2020-05-21-what-i-wish-someone-would-have-told-me-about-using-rabbitmq-before-it-was-too-late.md

# What I Wish Someone Would Have Told Me About Using RabbitMQ Before It Was Too Late

My watch is buzzing and in my pre-dawn stupor I cannot decipher if this is an alarm or a phone call. I finally pull it together at 4:45 AM to realize it's a call from a number I do not know - never a good sign. This call was from a coworker - my peer who runs our support team that is engaged in nearly all production issues for our customers. "Hi Ryan. Sorry to wake you, I know it's early. Our biggest customer is reporting their requests are taking over two hours to return results. We think it's because of our messaging system but we aren't sure where to go from here. Please join our call." A few moments later my watch buzzed again as my alarm went off but I quickly realized this morning would not be for a workout.

For nearly three years we have been running RabbitMQ for our production systems and 99.5% of the time has been a total non-issue. Throughout that time we have scaled to 200+ concurrent consumers running across a dozen virtual machines while coordinating message processing (1 queue to N consumers) and processed hundreds of millions of messages in our .NET application. Our primary use-case is making HTTP calls to another web service either retrieving JSON data or downloading PDF documents. I will tell you that I recommend RabbitMQ and that's because I do. For the most part it's been great to work with and it's performing well in our application. But, and this is a big but, all of this has come at a cost that we did not know at the time we made our architectural decisions.

RabbitMQ is the backbone of our polling architecture to check for job results. 
