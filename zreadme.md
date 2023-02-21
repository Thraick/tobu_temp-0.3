actions load module jac_nlp.use_qa
actions load module jac_nlp.bi_enc
actions load module jac_nlp.tfm_ner
actions load module jac_nlp.use_enc
actions load module jac_nlp.t5_sum
actions load module jac_nlp.zs_classifier
actions load module jac_nlp.cl_summer
actions load module jac_nlp.gpt2
actions load module jac_nlp.sbert_sim
actions load module jac_nlp.gpt3




actions load local utils/model/local/flow.py
actions load local utils/model/local/twilio_bot.py
actions load local utils/model/local/local_module.py
actions load local utils/model/local/tobu.py

graph delete active:graph
jac build main.jac
graph create -set_active true
sentinel register -set_active true -mode ir main.jir

walker run init



### tfm_ner // note for some reason tfm_ner_train only work on the server 


walker run tfm_ner_train -ctx "{\"train_file\": \"utils/data/tfm_train.json\"}"
walker run tfm_ner_infer -ctx "{\"labels\": [\"number\",\"accountName\",\"month\",\"accountNumber\"]}"
walker run tfm_ner_infer -ctx "{\"labels\": [\"event\",\"name\",\"activity\",\"emotion\",\"people\",\"subject\",\"age\",\"location\"]}"
walker run tfm_ner_save_model -ctx "{\"model_path\": \"tfm_ner_model\"}"
walker run tfm_ner_load_model -ctx "{\"model_path\": \"tfm_ner_model\"}"
walker run tfm_ner_delete



graph get -mode dot -o .main.dot
dot -Tpng .main.dot -o .main.png


jsserv makemigrations base
jsserv makemigrations
jsserv migrate
jsserv runserver 0.0.0.0:8008

jsserv createsuperuser

login http://localhost:8008



pip install jaseci --upgrade
pip install jac_nlp --upgrade
pip install jaseci-serv --upgrade

TODO 

- training data X ' in progress'
- summarizer and punctuator ' tomorrow' ' load model at work'
- fix queue_context ' done'
- running huh... when was this?  use previous data if there is one ' done'
- fix response unique response only ' done'
- update memory node with queue_context ' tomorrow'
- connect memories
- setup commentary with gpt 2 ' walker setup'
- zs_classifier 'not working' 
- add user to response
- check remove_list
- add more response
- 

