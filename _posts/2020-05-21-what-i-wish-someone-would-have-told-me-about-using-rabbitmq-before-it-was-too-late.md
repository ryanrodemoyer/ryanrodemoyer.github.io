---
layout: post
title: What I Wish Someone Would Have Told Me About Using RabbitMQ Before It Was Too Late
---

<div style="background-color: #F0F0F0; margin: 0; padding: 5px; border-radius: 5px;">
<p>November 2023 update: Fun fact, this post got decent traction on <a href="https://news.ycombinator.com/item?id=32091550" target="_blank">Hacker News</a> and <a href="https://www.reddit.com/r/programming/comments/w0f39y/what_i_wish_someone_would_have_told_me_about/" target="_blank">/r/programming</a> and I had no clue. Click the links if you're interested in those relevant discussions.
</p>
</div>

My watch is buzzing and in my pre-dawn stupor I cannot decipher if this is an alarm or a phone call. The time is 4:45 AM. I pull it together to realize it's a call from a number I do not know - never a good sign. I answer and it is a coworker - my peer who runs our support team that is engaged in nearly all production issues for our customers. "Hi Ryan. Sorry to wake you, I know it's early. Our biggest customer is reporting their requests are taking over two hours to return results. We think it's because of our messaging system but we aren't sure where to go from here. We need your help. Please join our call." A few moments later my watch buzzed again as my morning alarm sounded. Today, this morning will not be for a workout.

For nearly three years we have been running RabbitMQ for our production systems and 99.5% of the time has been a total non-issue. Throughout that time we have scaled to 200+ concurrent consumers running across a dozen virtual machines while coordinating message processing (1 queue to N consumers) and processed hundreds of millions of messages in our .NET application. Our primary use-case is making HTTP calls to another web service either retrieving JSON data or downloading PDF documents. I will tell you that I recommend RabbitMQ and that's because I do. For the most part it's been great to work with and it's performing well in our application. But, and this is a big but, all of this has come at a cost that we did not know at the time we made our architectural decisions.

RabbitMQ is the backbone of our polling architecture to check for job results. The typical action sequence is the user submits a request via the web application and the backend handles that message by adding a message to RabbitMQ. The consumer gets the message and makes a HTTP call to another web service to actually submit the request. From there, the polling logic takes over and subsequent messages on the queue each represent a polling attempt to retrieve the results. If a job has no results, the consumer places a message back on a queue so we can delay the next polling attempt by a (customer configurable) amount of time. Our delay logic uses a network of queues with a time-to-live (TTL) and dead letter definitions.

Our non-prod clusters use either two or three nodes while production clusters use three nodes. Every cluster has a load balancer and the application strictly addresses only the load balancer. At run time, the publishers and consumers use the same load balancer.

Back to business, you're reading because you want the goods and not this poorly written synopsis of our application.

# What You Should Know

Three years after implementation, this is what I would tell myself before I wrote a single line of code interacting with RabbitMQ.

## Engage an expert at the beginning

For probably $2000-$3000 (guesstimate) you can engage a RabbitMQ consulting firm and get time with an expert. Use this opportunity to vet and verify your assumptions, plan, ask questions, get recommendations and perform due diligence so you can minimize future headaches, problems and _most likely_ save money in the long run by making the correct decisions now. Or you can take our route, engage the expert when shit is going sideways.

## Use a library like EasyNetQ or NServiceBus

Our application uses the `RabbitMQ.Client` library from RabbitMQ and these abstraction libraries (ex. EasyNetQ, NServiceBus) use it too. However they're better and know way more than I ever will about interacting with RabbitMQ at such a low level. The driver from RabbitMQ is low level, primitive and expects you to understand nuance about RabbitMQ. If this is your first time with RabbitMQ then I guarantee you will not have experience to appreciate this nuance.

Before you ask "Why didn't you use a wrapper library?" let me tell you. In my case, our RabbitMQ project landed in my lap when the original developer left the company near the end of the implementation and he decided to use the `RabbitMQ.Client` library directly. I did not have enough time to make that swap (nor did I know I should have made a case to swap for a wrapper library!).

## There's this Network Partition thing, it's kind of a big deal

For common terminology, your RabbitMQ system is called a cluster. A cluster is comprised of one or more nodes. A node is simply a server/container running the RabbitMQ software. All nodes in a cluster must run the same exact version of RabbitMQ.

RabbitMQ provides a mechanism called clustering so that you can link other RabbitMQ instances so they function together as a single logical broker. You can address any node in the cluster with any request and the nodes will cooperate to publish the message or send the message to a consumer.

The nodes are communicating with each other constantly by exchanging data about messages, queues, exchanges, etc. If (and when) that communication is interrupted even if only for a few milliseconds then RabbitMQ enteres a partitioned state and looks to the configuration file to determine what to do about this communication interruption. **The default partition handling strategy is `ignore` which means to just enter the partitioned state and keep trucking along in this "split brain" mode thereby thrusting your cluster in to total chaos.** This was hell for us (and a lot of hell for me). The only way to exit the parition to restart the nodes of one side of the partition so it will then rejoin the other side and assume their data **thereby discarding it's own data set that it accumulated while the cluster was partitioned**.

I have personally experienced network partions happening in two ways: all nodes in the cluster being updated at the same time through Windows update and firewall rules. The fix for Windows update was the ensure that nodes in the cluster are patched at different times.

I have to stop myself as I could continue to rant and rave about this topic for countless words. The correct configuration is to set the `partion_handling` strategy to `pause_minority`. When the cluster is partitioned, one side of the partition will simply turn itself off thereby totally avoiding the split brain scenario. The side that is off will continue to monitor the cluster for resumed communications and will rejoin itself at that time. Now all you have to do is ensure your code properly handles disconnected connections and you will have a fairly robust queuing solution.

From CAP Theorm, `ignore` means to sacrifice Consistency at the expense of Availability while `pause_minority` is to sacrifice Availability at the expense of Consistency. The latter is quite worth it, if you're asking me.

## How are you going to upgrade RabbitMQ versions?

The day will come when your version of RabbitMQ has reached end of life. Then what do you do? Continue to operate the unsupported version? Create a new cluster? What will be your plan to migrate traffic from the legacy cluster to the new cluster? Recall my note (above) that all nodes in a cluster need to run _the same exact version_. Hopefully you can see how this will be tricky if your plan will be to upgrade the nodes in-place.

I leave you only with questions, no answers. This is because every decision is highly dependent on your organizational and operational strategies. In other words, everyone might have a bit of a different approach to solve for these problems.

## What's your plan if you lose all messages in RabbitMQ?

How screwed will you be if you were to lose all (or even a third) of your messages in RabbitMQ? Is RabbitMQ your system of record? Do you have a recovery strategy for getting your application back in to a functional state? What happens when you move your on-prem servers to the cloud - how do you get your RabbitMQ messages flowing again?

## Build your application to support different connection addresses for publishers and consumers

At some point in the future (perhaps during an upgrade) you will want the flexibility to independently publish to and consume from different clusters and/or load balancers. This is a zero-risk-high-reward pattern you can early-on build in your application for where you will pat yourself on the back in the future.

## The log files will grow to consume dozens of gigabytes of disk space

The log files from RabbitMQ will, over time, grow to consume dozens of gigabytes of disk space. It's easy enough to rotate those files using `rabbitmqctl rotate_logs` but strive to automate a process so that "running out of disk space" never causes an outage.

# Conclusion

RabbitMQ has been a long-term solid addition to our infrastructure and you are probably making a good decision to use this tool. However, you should also take seriously what I have brought up and at least have a conversation with your peers and stakeholders to decide what about these pain points you should try to address.
