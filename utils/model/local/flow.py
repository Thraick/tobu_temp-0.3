import random
from jaseci.actions.live_actions import jaseci_action  # step 1
import json
import os
from typing import Union

import string
from fastpunct import FastPunct
from textblob import TextBlob



dir_path = os.path.dirname(os.path.realpath(__file__))
fastpunct = FastPunct()

@jaseci_action(act_group=["flow"], allow_remote=True)
def fix_sentence(sentence):
    sentence1 = sentence.translate(str.maketrans('', '', string.punctuation))
    # sentence2 = correct(sentence1)
    blob = TextBlob(sentence1)
    sentence2 = blob.correct()
    sentence3 = fastpunct.punct([sentence2])

    return sentence3[0]

@jaseci_action(act_group=["flow"], allow_remote=True)
def check_required_entity(entity_list: list, ext_list: list):
    result = False
    for entity in entity_list:
        if any(entity == i for i in ext_list):
            result = True
        else:
            result = False
            break
    return result

@jaseci_action(act_group=["flow"], allow_remote=True)
def select_event_response(state_ext_item: dict, state_response: list, dial_context: dict, event:list):
    response_name = ""
    response = ""
    dic = {}
    
    if (state_ext_item):
        dialog_key = list(dial_context.keys())

        for item in state_ext_item:
            if item not in dialog_key and item in event:
                response_name = item
                response = random.choice(state_ext_item[item])
                dic["name"]= response_name
                dic["response"]= response
                break
    if response == "":
        response = random.choice(state_response)
        dic["name"]= response_name
        dic["response"]= response
    return dic

@jaseci_action(act_group=["flow"], allow_remote=True)
def select_response(state_ext_item: dict, state_response: list, dial_context: dict):

    response_name = ""
    response = ""
    dic = {}


    if (state_ext_item):
        context_key = list(dial_context.keys())
        for item in state_ext_item:
            if item not in context_key:
                response_name = item
                response = random.choice(state_ext_item[item])
                dic["name"]= response_name
                dic["response"]= response
                break
    if response == "":
        response = random.choice(state_response)
        dic["name"]= response_name
        dic["response"]= response
    return dic

@jaseci_action(act_group=["flow"], allow_remote=True)
def info_json(resource: str, dial_context: dict, variable):

    open_json = resource

    my_dict = {}
    info_id_1 = variable[0]
    info_id_2 = variable[1]
    my_list = []

    for item in dial_context:
        if type(dial_context[item]) is str:
            my_dict[item] = dial_context[item]
        else:
            my_dict[item] = dial_context[item][0]

    if (resource):
        with open(open_json) as f:
            data_set = json.load(f)
        for data in data_set:
            if data[info_id_1] in dial_context[info_id_1]:
                # print(info_id_1)
                my_dic = {}
                for item in variable:
                    my_dic[item] = data[item]
                my_list.append(my_dic)
            elif data[info_id_2] in dial_context[info_id_1]: #  and len(dial_context[info_id_1][0]) == 5
                # print(info_id_2)
                my_dic = {}
                for item in variable:
                    my_dic[item] = data[item]
                my_list.append(my_dic)

    my_dict["info_json"]= my_list
    return my_dict

@jaseci_action(act_group=["flow"], allow_remote=True)
def collect_info(collect_info: dict, my_dict: dict):

    dict_key = list(my_dict.keys())


    for key, value in collect_info.items():
        if key not in dict_key:
            return [key, value]
    
    return ["",""]

@jaseci_action(act_group=["flow"], allow_remote=True)
def gen_response(response_list: list, dial_context: dict, prev_response: Union[str, None]):

# Keep selecting a random item until it is different from the previously selected item
    i = 0
    while True:
        
        response = random.choice(response_list)
        print(response)
        if response != prev_response and len(response) > 1:
            break
        else:
            
            if (i > len(response_list)):
                print("break")
                break
            i += 1
            print("Error in gen response: ")
            print("prev_response")
            print(prev_response)
            print(i)
        # Update the previously selected item to the current one
        prev_response = response


    
    
    answer = ""
    my_dict = {}
    # print(dial_context)

    if dial_context:
        for item in dial_context:
            if isinstance(dial_context[item], list):
                # print("list")
                my_dict[item] = dial_context[item][0]
            else:
                # print("list no")
                my_dict[item] = dial_context[item]
    # print("my_dict")
    # print(my_dict)

    if "{{" in response and my_dict:
        l1 = response.replace('{{', '{')
        l2 = l1.replace('}}', '}')
        answer = l2.format(**my_dict)
    else:
        answer = response

    return answer

@jaseci_action(act_group=["flow"], allow_remote=True)
def check_response(response:str):
    if "{{" in response and "}}" in response:
        return True
    else: 
        return False

@jaseci_action(act_group=["flow"], allow_remote=True)
def select_options(response: str, my_dict: dict, variable:list):
    
    my_lis = []
    item = variable[-1]

    for a in my_dict['info_json']:
        my_lis.append(a[item])
    
    lis1 =', '.join(map(str, my_lis[:-1]))
    lis2 = my_lis[-1]

    new_dict= my_dict.copy()
    new_dict["first_"+item]=lis1
    new_dict["last_"+item]=lis2
    new_dict["num_"+item]= len(my_dict['info_json'])

    l1 = response.replace('{{', '{')
    l2 = l1.replace('}}', '}')
    answer = l2.format(**new_dict)

    return answer


@jaseci_action(act_group=["flow"], allow_remote=True)
def select_ent_response(my_text:str, my_dict:dict):
      
    placeholders = [placeholder.strip(" {}") for placeholder in my_text.split("{{") if "}}" in placeholder]
    my_clean_list = [item[:item.index("}}")].strip("}") for item in placeholders if "}}" in item]

    for item in placeholders:
        if "}}" not in item:
            my_clean_list.append(item.strip("}"))

    if all([placeholder in my_dict for placeholder in my_clean_list]):
        return my_text
