
global main_root = '';
global dialogue_root = '';

global faq_score = 0.2;
global conv_score = 0.5;

global train_state_path = 'utils/data/state.json';
global train_faq_answer_path = 'utils/data/faq_answer.json';
global train_classifer_path = 'utils/data/classifer_data.json';
global train_tfn_ner_path = 'utils/data/tfm_train.json';

global entity_label =[];
global prev_response = "";
// summary
global sentiment_descriptors_path = "utils/data/summary/sentiment_descriptors.json";
global events_path = "utils/data/summary/events.json";
global sentiments_path = "utils/data/summary/sentiments.json";
global commentary_path = "utils/data/commentary.json";
global emotion_score = 0.1;
global entity_response_score = 0;

global sentiment_descriptors = {
    "sad": ["sorrowful", "unfortunate", "sad", "unhappy","Gloomy","Disheartened","Pessimistic","Bleak","Miserable","Melancholic","Despondent","Dejected","Dispirited","Heartbroken","Devastated","Desolate","Wretched","Forlorn","Disappointed","Distraught","Grieved","Anguished","Lonely","Hopeless"],
    "happy": ["pleasant", "lovely", "great", "beautiful", "Joyful","Delighted","Ecstatic","Thrilled","Pleased","Grateful","Overjoyed","Blissful","Content","Cheerful","Amused","Elated","Euphoric","Radiant","Exhilarated","Enchanted","Smitten","Infatuated","Enamored","Over the moon"],
    "fear": ["thrilling", "frightening", "unsettling", "disturbing"],
    "anger": ["angry", "frustrating", "hair-pulling", "annoying"],
    "surprised": ["surprising", "insane", "shocking", "jolting"]
};

global sentiments = {
    "sad": ["I'm sorry to hear that.", "Oh dear, that's so sad!", "I'm terribly sorry to hear that."],
    "happy": ["Awesome!", "I'm so happy for you!", "That's wonderful!", "How nice.."],
    "fear": ["That's scary!", "That's terrifying!"],
    "anger": ["I'm sorry that you're mad, it'll be ok..'", "Try to stay calm, ok?", "I'm sorry that you are angry!"],
    "surprised": ["Wow, that's surprising!", "Amazing!, I know you are surprised indeed!"]
};

// global to_remove = ["Yes ", "No ", "Oh ", "yes ", "no ", "oh ","yes", "no", "oh", "Yes", "No", "Oh", "I don't know", "i don't know", "i dont know", "I dont know", "Save it", "save it", "yeah"," Yeah", "nah", "Nah", "nope", "Nope", "yea", "Yea"];

// global to_remove = ['yes', 'no', 'oh', "i don't know", 'nope', 'yeah', 'nah', 'maybe', 'possibly', 'perhaps', 'sorry', 'please', 'thank you', 'okay', 'alright', 'uh-huh', 'uh-uh', 'oops', 'huh', 'ugh', 'yikes', 'meh', 'mhm', 'gotcha', 'well', 'you know', 'so'];
global to_remove = ['yes', 'no', 'oh', "i don't know", 'nope', 'yeah', 'nah', 'maybe', 'possibly', 'perhaps', 'sorry', 'please', 'thank you', 'okay', 'alright', 'uh-huh', 'uh-uh', 'oops', 'huh', 'ugh', 'yikes', 'meh', 'mhm', 'gotcha', 'well', 'you know', 'so', 'kinda', 'sorta', 'basically', 'actually', 'literally', 'seriously', 'definitely', 'absolutely', 'totally', 'completely', 'utterly', 'quite', 'pretty', 'fairly', 'rather', 'somehow', 'somewhat', 'anyway', 'anyhow', 'anyways', 'alas', 'voila', 'ta-da'];
