import re
from jaseci.actions.live_actions import jaseci_action  # step 1

@jaseci_action(act_group=["local"], allow_remote=True)
def entity_value(utterance:str, utterance_list:list):
    lis = []
    if utterance_list:
        for utterance in utterance_list:
            m = re.findall(r"\[([A-Za-z0-9_-]+)\]", utterance)
            n = re.findall(r"\(([A-Za-z0-9_-]+)\)", utterance)

            data = {"value": m, "entity": n, "utterance": utterance}
            lis.append(data)
    else:
        m = re.findall(r"\[([A-Za-z0-9_-]+)\]", utterance)
        n = re.findall(r"\(([A-Za-z0-9_-]+)\)", utterance)

        data = {"value": m, "entity": n, "utterance": utterance}
        lis.append(data)
    return lis


from transformers import T5Tokenizer, T5ForConditionalGeneration
from pprint import pprint

@jaseci_action(act_group=["local"], allow_remote=True)
def paraphraser(input_text:str):
    model = T5ForConditionalGeneration.from_pretrained('prithivida/parrot_paraphraser_on_T5')
    tokenizer = T5Tokenizer.from_pretrained('prithivida/parrot_paraphraser_on_T5')

    # input_text = "yesterday was Anna's birthday. This was taken at home in Ann Arbor." 
    # input_text = "yesterday was Anna's birthday. This was taken at home in Ann Arbor. we had an amazing time." 
    # input_text = "yesterday was Anna's birthday. This was taken at home in Ann Arbor. we had an amazing time,  Anna is 22 years old" 
    # input_text = "yesterday was Anna's birthday This was taken at home in Ann Arbor we had an amazing time  Anna is 22 years old it was just my friends" 

    # input_text = "Natural Language Processing can improve the quality life."

    batch = tokenizer(input_text, return_tensors='pt')

    # generated_ids = model.generate( batch['input_ids'],
    #                                 num_beams=5,
    #                                 num_return_sequences=5,
    #                                 temperature=1.5,
    #                                 num_beam_groups=5,
    #                                 diversity_penalty=2.0,
    #                                 no_repeat_ngram_size=2,
    #                                 early_stopping=True,
    #                                 length_penalty=2.0,
    #                                 max_new_tokens = 200
    #                                 )

    generated_ids = model.generate( batch['input_ids'],
                                    num_beams=5,
                                    temperature=1.5,
                                    no_repeat_ngram_size=2,
                                    early_stopping=True,
                                    length_penalty=2.0,
                                    max_new_tokens = 200
                                    )

    generated_sentence = tokenizer.batch_decode(generated_ids, skip_special_tokens=True)
    return generated_sentence

# input_text = "yesterday was Anna's birthday This was taken at home in Ann Arbor we had an amazing time  Anna is 22 years old it was just my friends" 
# tt = paraphraser(input_text)
# pprint( tt)


import requests


from happytransformer import HappyTextToText, TTSettings

@jaseci_action(act_group=["local"], allow_remote=True)
def happy_transformer(payload:str):



    happy_tt = HappyTextToText("T5", "vennify/t5-base-grammar-correction")

    args = TTSettings(num_beams=10, min_length=1, max_length=300)

    # Add the prefix "grammar: " before each input 
    result = happy_tt.generate_text("grammar:" + payload, args=args)
    
    return result.text


# ss = "I went walking in the park in france. This was taken at home in Ann Arbor. it was just my friends. this happened yesterday. it was amazing"

# print(happy_transformer(ss))


from transformers import pipeline


@jaseci_action(act_group=["local"], allow_remote=True)
def grammar_synthesis(payload:str):
    corrector = pipeline(
                'text2text-generation',
                'pszemraj/grammar-synthesis-base',
                )

    results = corrector(payload)
    return results[0]['generated_text']


@jaseci_action(act_group=["local"], allow_remote=True)
def shorten_str(text:str, max_length:int):

    shortened_sentence = text[:max_length]
    return shortened_sentence



from fastpunct import FastPunct
# The default language is 'english'
fastpunct = FastPunct()

@jaseci_action(act_group=["local"], allow_remote=True)
def punctuate(text:list):
    ss = fastpunct.punct(text,
        correct=True
    )
                   
    return ss


# ff = ["yesterday was anna's birthday i had a great time with my friends this happened at ann arbor she is 22"]
# print(punctuate(ff))
@jaseci_action(act_group=["local"], allow_remote=True)
def add_full_stop(sentences:list):
    sent2 =[]
    ww =[]
    for i in range(len(sentences)):
        ss3 = sentences[i].rstrip()
        ww.append(ss3)
        
    for i in range(len(ww)):
        if not ww[i].endswith("."):
            ww[i] = ww[i] + ". "
            sent2.append( ww[i].capitalize())


    return sent2

# ss = add_full_stop(["this is good  ", "this is good33 "])
# print(ss)

