actions load module jac_nlp.use_qa
actions load module jac_nlp.bi_enc
actions load module jac_nlp.tfm_ner
actions load module jac_nlp.use_enc
actions load module jac_nlp.t5_sum
actions load module jac_nlp.zs_classifier
actions load module jac_nlp.cl_summer

actions load local utils/model/local/flow.py
actions load local utils/model/local/twilio_bot.py
actions load local utils/model/local/local_module.py
actions load local utils/model/local/tobu.py

graph delete active:graph
jac build main.jac
graph create -set_active true
sentinel register -set_active true -mode ir main.jir

walker run init




walker run talk -ctx "{\"question\": \"yesterday was Anna's birthday.\"}"
walker run talk -ctx "{\"question\": \"yesterday was Anna's birthday. it was amazing\"}"
walker run talk -ctx "{\"question\": \"we went to a trip in france.\"}"
walker run talk -ctx "{\"question\": \"yesterday was Anna's birthday. we went on a vacation\"}"
walker run talk -ctx "{\"question\": \"This was taken at home in Ann Arbor\"}"
walker run talk -ctx "{\"question\": \"it was amazing\"}"
walker run talk -ctx "{\"question\": \"Anna is 22 years old\"}"
walker run talk -ctx "{\"question\": \"it was just my friends\"}"
walker run talk -ctx "{\"question\": \"it was mostly sunny there\"}"



walker run talk -ctx "{\"question\": \"i was with my friends. It was amazing\"}"

walker run talk -ctx "{\"question\": \"This was taken at home in Ann Arbor. we had an amazing time\"}"


walker run talk -ctx "{\"question\": \" yes, save it\"}"
walker run talk -ctx "{\"question\": \"Let's not save it\"}"
walker run talk -ctx "{\"question\": \"yes Absolutely\"}"
walker run talk -ctx "{\"question\": \"i dont know\"}"

walker run talk -ctx "{\"question\": \"no\"}"
walker run talk -ctx "{\"question\": \"I went walking in the park in france.\"}"

walker run talk -ctx "{\"question\": \"I went to the park yesterday.\"}"
walker run talk -ctx "{\"question\": \"it was just my friends\"}"
walker run talk -ctx "{\"question\": \"this happened yesterday\"}"
walker run talk -ctx "{\"question\": \"it was amazing\"}"
walker run talk -ctx "{\"question\": \"no\"}"

walker run talk -ctx "{\"question\": \"This was taken at home in Ann Arbor\"}"



walker run talk -ctx "{\"question\": \"it was just my son\"}"


walker run talk -ctx "{\"question\": \"I went walking in the park in france.\"}"
walker run talk -ctx "{\"question\": \"I went to the park yesterday.\"}"
walker run talk -ctx "{\"question\": \"i went walking yesterday\"}"
walker run talk -ctx "{\"question\": \"i felt amazing\"}"

walker run talk -ctx "{\"question\": \"john and tim was there and they were anna's oldest friends\"}"
walker run talk -ctx "{\"question\": \"no\"}"
walker run talk -ctx "{\"question\": \"It was really amazing\"}"
walker run talk -ctx "{\"question\": \"We ate cake and play cricket\"}"


walker run get_memories

TODO
- Fix image
- Add data to remove_list eg: "Nah nah it's all good"
- Fix unanswered_queue
- Add user to reply

- training data X
- summarizer and punctuator 
- fix queue_context