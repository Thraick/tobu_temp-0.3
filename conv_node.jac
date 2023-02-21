
node dialogue_state{
    has imprint;
    has name;

    // hold threshold list
    // ai kit 
    can bi_enc.infer;
    can tfm_ner.extract_entity;
    can use.text_classify;

    // custom modules
    can flow.info_json;
    can flow.select_response;
    can flow.gen_response;
    can flow.collect_info;
    can flow.select_options;
    can twilio.twilio_bot;
    can flow.check_required_entity;

    can classify_intent {
        if(visitor.respond){

            imprints = -[intent_transition]->.imprint;
            intent_labels = -[intent_transition]->.edge.intent;
            std.out("intent_labels");
            std.out(intent_labels);
            max_score = global.conv_score;
            intent = "";

            for imprint in imprints {
                if (imprint[0].type == dict ){

                    best_answer = use.text_classify(
                        text = visitor.question,
                        classes = imprint[0]['list_imprint'].list
                    );
                    nn = best_answer['match_idx'];
                    if (best_answer['scores'][nn] > max_score){
                        max_score = best_answer['scores'][nn];
                        intent = imprint[0].name;
                    }
                }
            }
            
            if (max_score > global.conv_score and intent in intent_labels){
                visitor.threshold = true;
                visitor.predicted_intent = intent;
            }
            std.log("THRESHOLD: ", global.conv_score,"   SCORE: " , max_score);
            std.log("INTENT:  ", visitor.predicted_intent);
        }
    }

    can extract_entities {
        if(visitor.respond){
            res = tfm_ner.extract_entity(visitor.question);
            if(res.type == list || res.type == dict){

                for ent in res {
                    ent_type = ent["entity_value"];
                    ent_text = ent["entity_text"];
                    if ( !(ent_type in visitor.extracted_entities) ){
                        visitor.extracted_entities[ent_type] = [];
                    }
                    
                    if( ent_text not in visitor.extracted_entities[ent_type] ){
                        visitor.extracted_entities[ent_type].l::append(ent_text);
                    }
                }
            }
            std.log("ENTITIES:  ", visitor.extracted_entities);
        }
    }

    can business_logic {
        visitor.dialogue_context.dict::update(visitor.extracted_entities);
        for label in global.entity_label {
            if (label in visitor.extracted_entities) {
                visitor.dialogue_context[label]=visitor.extracted_entities[label][0];
            }
        }
    }

    can nlu with talk entry {}

    can process with talk entry {
        if(visitor.respond){

            required_entities = -[entity_transition]->.edge.entities;
            redirect = -[redirect_transition]->;

            if(visitor.extracted_entities and !visitor.next_state){
                if(required_entities){
                    for entity in required_entities{
                        required = flow.check_required_entity(entity, visitor.extracted_entities.d::keys);
                        if(required == true){
                            visitor.next_state = -[entity_transition(entities == entity)]->[0];
                        }
                        elif(visitor.predicted_intent2){
                            visitor.next_state = -[intent_transition2(intent2 == visitor.predicted_intent2)]->[0];
                        }
                        elif(visitor.predicted_intent){
                            visitor.next_state = -[intent_transition(intent == visitor.predicted_intent)]->[0];
                        }
                        elif(redirect){
                            visitor.next_state = -[redirect_transition]->[0];
                        }
                        else{
                            // std.out('NOTE_: Can Process else ran 2!');
                        }
                    }
                }
                elif(visitor.predicted_intent2){
                    visitor.next_state = -[intent_transition2(intent2 == visitor.predicted_intent2)]->[0];
                }
                elif(visitor.predicted_intent){
                    visitor.next_state = -[intent_transition(intent == visitor.predicted_intent)]->[0];
                }
                elif(redirect){
                    visitor.next_state = -[redirect_transition]->[0];
                }
                else{
                    // std.out('NOTE_: Can Process else ran 3!');
                }
            }
            elif(visitor.predicted_intent2){
                visitor.next_state = -[intent_transition2(intent2 == visitor.predicted_intent2)]->[0];
            }
            elif(visitor.predicted_intent and visitor.threshold ){
                visitor.next_state = -[intent_transition(intent == visitor.predicted_intent)]->[0];
            }
            elif(redirect and !visitor.next_state){
                visitor.next_state = -[redirect_transition]->[0];
            }
            else{
                // std.out('NOTE_: Can Process else ran 1!');
            }
        }
    }

    can nlg with talk entry {
        if (!visitor.respond) {
            report {
                "question": visitor.question,
                "name": here.name,
                "response": visitor.response
            };
        }
    }

    can cleanup with talk entry {
        intent_labels = -[intent_transition]->.edge.intent;
        if(intent_labels.length == 0){
            visitor.prev_state = global.dialogue_root;
        }
        else{
            visitor.prev_state = here.info['jid'];
        }
        spawn *(global.main_root) walker::maintainer( 
            prev_state = visitor.prev_state,
            dialogue_context = visitor.dialogue_context,
            // queue_context = queue_context,
            unanswered_queue = visitor.unanswered_queue
        );
    }
}


node dialog:dialogue_state{
    has name="dialogue_root";

    can nlu with talk entry{
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        visitor.response = "This is the dialogue root!!";
    }
}


node faqs:dialogue_state{
    has name;
    has classifier;

    can use.qa_classify;

    can nlu with talk entry{
        answers = -[faq]->.answer;
        best_answer = use.qa_classify(
            text = visitor.question,
            classes = answers
        );
        max_score = global.faq_score;
        nn = best_answer['match_idx'];
        std.log( "FAQ: " + " MATCH: ",best_answer['match'],"   SCORE: " ,best_answer['scores'][nn]);

        if (best_answer['scores'][nn] > max_score){
            visitor.response = best_answer['match'];
        }
    }

    can process with talk entry{
        if(visitor.prev_state){
            visitor.next_state = *(visitor.prev_state);
        }
        else{ 
            visitor.next_state = global.dialogue_root;
        }
    }

    can cleanup with talk entry{}

}


node faq{
    has name;
    has answer;
}


node user {
    has id;
    has prev_state = null;
    has dialogue_context ={};
    // has queue_context = {};
    has unanswered_queue = [];

    can start_conv with talk entry {
        if (here.prev_state == null) {
            here.prev_state = global.dialogue_root;
        }
        visitor.cont_state = here.prev_state;
        visitor.dialogue_context = here.dialogue_context;
        // queue_context = here.queue_context;
        visitor.unanswered_queue = here.unanswered_queue;
    }

    can update_with_conv with maintainer entry {
        here.prev_state = visitor.prev_state;
        here.dialogue_context = visitor.dialogue_context;
        // here.queue_context = queue_context;
        here.unanswered_queue = visitor.unanswered_queue;

    }
}


node summary_template:dialogue_state{
    has name;

    can local.paraphraser;
    can flow.fix_sentence;
    can cl_summer.summarize;
    can local.happy_transformer;
    can local.grammar_synthesis;
    can local.shorten_str;
    can local.punctuate;
    can local.add_full_stop;



    can summarize{ 
        // std.out("visitor.dialogue_context['queue_context']");
        // std.out(visitor.dialogue_context['queue_context']);

        
        // sentence = ' '.str::join(visitor.dialogue_context["extracted_sentences"]);
        // std.out("sitor.dialogue_context['extracted_sentences']");
        // std.out(visitor.dialogue_context["extracted_sentences"]);
        sss = local.add_full_stop(visitor.dialogue_context["extracted_sentences"]);
        sentence = ''.str::join(sss);

        sentence2 = "";
        sentence1 = "";

        std.out("Inside sentence");

        for s in global.to_remove{
            if(s in sentence){
                std.out(s);
                sentence1 = sentence.str::replace(s.str, "");
            }
        }
        // happy_transformer_result = local.happy_transformer(sentence2);
        // sentence2= local.grammar_synthesis(payload=sentence1);
        // sentence2 = local.punctuate(text=[sentence1]);
        sentence2 = [sentence1];
        // std.out("\n\nsentence2");
        // std.out(sentence2);
        
        // subject_title = spawn here walker::summary(text=sentence2); // subjuct problem
        // gs_description = spawn here walker::summary(category="description",text=sentence2[0]);
        
        
        subject_title_1 = local.shorten_str(text= sentence2[0], max_length=35);
        subject_title = subject_title_1 + "...";
        // std.out("subject_title");
        // std.out(subject_title);
        gs_description = sentence2[0];


        visitor.dialogue_context["summary"] = sentence2[0];
        if(visitor.image_urls){
            spawn *(global.main_root) walker::create_memory(memory_context=visitor.dialogue_context, image_urls=visitor.image_urls, subject_title = subject_title, gs_description=gs_description);
        }
        else{
            spawn *(global.main_root) walker::create_memory(memory_context=visitor.dialogue_context, subject_title = subject_title, gs_description=gs_description);
        }
    }

    can nlu with talk entry {
        if !(visitor.respond){
            ::classify_intent;
            ::extract_entities;
            ::business_logic;

            ::summarize;
            

            state_json = file.load_json(global.train_state_path);
            for state in state_json{
                if (!visitor.respond) {
                    if (here.name == state["name"].str){
                        arry = flow.select_response({}, state['responses'], {});
                        

                        visitor.response = arry['response'] + " " + visitor.dialogue_context["summary"];
                    }
                }
            }
        }
        // clear node and walker
    }

}


node capture_memories:dialogue_state {

    // main vairables
    has default_queue=["location","people","date","emotion"]; // default_entities;
    // has main_queue= default_queue;
    has main_queue=["location","people","date","emotion"];
    has answered_queue=[];
    // has unanswered_queue=[]; // unanswered_queue replace visitor.unanswered_queue

    has queue_context = {}; // queue_context replace queue_context
    has test_ev_type = {};
    has ev_type=[];
    // has event_name = [];
    // has answer_list = [];
    has removed_queue;
    // has item_name = [];
    has remove_context = [];
    // has sentiment = ""; // sentiment replace visitor.sentiment
    has first_response = true;
    has event_name = [];
    has item_name = [];

    // path to json
    has response_entity = file.load_json("utils/data/queue.json");
    has events_type = file.load_json("utils/data/summary/events.json");
    has activities_type = file.load_json("utils/data/summary/activities.json");
    has sentiments = file.load_json("utils/data/summary/sentiments.json");
    has commentary_json = file.load_json(global.commentary_path);

    has queue_context_key = "";
    has delete_entitiy = [];

    can zs_classifier.classify;
    can flow.select_ent_response;
    


    can classify_entity{
        // std.out("classify_entity");
        // std.out(visitor.respond);
        if("event" in visitor.extracted_entities){
            zs_result =  zs_classifier.classify(text=visitor.question, classes=events_type.dict::keys);
            if(visitor.question in zs_result[0]){
                if (zs_result[0][visitor.question]){
                    ev_type=[];
                    for item in zs_result[0][visitor.question]{  
                        zs_entity_name = item["value"];
                        if (item['confidence'] > 0.75 and zs_entity_name not in ev_type and zs_entity_name in events_type){ 
                            data = {};
                            test_ev_type[zs_entity_name]=events_type[zs_entity_name];
                            ev_type.list::append(zs_entity_name);
                            break;
                        }
                    }
                }
            }
            // std.out("visitor.question");
            // std.out(visitor.question);
            // std.out("zs_result");
            // std.out(zs_result);
        }





        if("activity" in visitor.extracted_entities){
            // std.out("activities_type");
            // std.out(activities_type.dict::keys);
            zs_result =  zs_classifier.classify(text=visitor.question, classes=activities_type.dict::keys);
            // std.out("zs_result");
            // std.out(zs_result);
            if(visitor.question in zs_result[0]){
                if (zs_result[0][visitor.question]){
                    ev_type=[];
                    for item in zs_result[0][visitor.question]{
                        zs_entity_name = item["value"];
                        // std.out("zs_entity_name");
                        // std.out(zs_entity_name);
                        if (item['confidence'] > 0.75 and zs_entity_name not in ev_type and zs_entity_name in activities_type){ 
                            data = {};
                            test_ev_type[zs_entity_name]=activities_type[zs_entity_name];
                            ev_type.list::append(zs_entity_name);
                            // std.out("inside if confidence");
                            break;
                        }
                    }
                }
            }
            // std.out("visitor.question");
            // std.out(visitor.question);
            // std.out("zs_result");
            // std.out(zs_result);
        }
        // std.out("test_ev_type");
        // std.out(test_ev_type);
        

        if(event_name){
            zs_result =  zs_classifier.classify(text=visitor.question, classes=event_name);
            if(visitor.question in zs_result[0]){
                if (zs_result[0][visitor.question]){
                    ev_type=[];
                    for item in zs_result[0][visitor.question]{
                        zs_entity_name = item["value"];
                        // std.out("zs_entity_name");
                        // std.out(zs_entity_name);
                        if (item['confidence'] > 0.75 and zs_entity_name not in ev_type and zs_entity_name in event_name){ 
                            data = {};
                            // test_ev_type[zs_entity_name]=activities_type[zs_entity_name];
                            if (zs_entity_name not in ev_type){
                                ev_type.list::append(zs_entity_name);
                            }
                            // std.out("inside if confidence");
                            break;
                        }
                    }
                }
            }
        }

        if(queue_context_key not in ev_type and visitor.respond){
            // std.out("context key yyyyyyyyy");
            ev_type = [];
            ev_type.list::append(queue_context_key);
        }

        // std.out("events_type");
        // std.out(events_type);
        
    }

    can update_queue{
        // std.out("update_queue");
        // std.out(visitor.respond);
        ::classify_entity;
        // event_name = [];
        // item_name = [];

        for ent in visitor.extracted_entities{
            // std.out('this happened 22222');
            for m_ent in main_queue{
                if (m_ent.type == dict and visitor.respond){
                    // std.out("m_ent");
                    // std.out(m_ent);
                    // std.out(m_ent.dict::keys[0]);
                    // std.out(ev_type);
                    // std.out("queue_context_key");
                    // std.out(queue_context_key);
                    if(ent in m_ent.dict::values[0] and m_ent.dict::keys[0] in ev_type){
                        // std.out("dont add to ev_type");
                        // if(queue_context_key not in ev_type){
                        //     std.out("context key yyyyyyyyy");
                        //     ev_type.list::append(m_ent.dict::keys[0]);
                        // }
                        break;
                    }
                    elif(ent in m_ent.dict::values[0] and m_ent.dict::keys[0] not in ev_type and "event" not in visitor.extracted_entities){
                        // if (m_ent.dict::keys[0] not in ev_type){
                            // std.out('this happened 77722222222227');
                            ev_type.list::append(m_ent.dict::keys[0]);
                        // }
                    }
                    // else{
                    //     std.out("")
                    // }
                    // elif (m_ent.dict::keys[0] not in ev_type){
                    // else{
                    //     std.out('this happened 7777');
                    //     ev_type.list::append(m_ent.dict::keys[0]);
                    // }
                }
            }
        }

        // update visitor.unanswered_queue
        // if(visitor.respond and removed_queue and removed_queue not in visitor.extracted_entities.dict::keys){
        //     // if (removed_queue): visitor.unanswered_queue.list::insert(0, removed_queue);
        //     visitor.unanswered_queue.list::insert(0, removed_queue);
        // }
        // std.out("This work 3");
        // std.out("\n\n\nevent_name");
        // std.out(event_name);

        
        
        // event and activity logics
        if( "event" in visitor.extracted_entities or "activity" in visitor.extracted_entities and !visitor.respond){
            // std.out("This work 1");
            // std.out(test_ev_type);
            // std.out(event_name);
            for event in test_ev_type{
                if(event not in event_name){ 
                    queue_context[event]={}; 
                    event_dict = {};
                    event_dict2 = {};

                    event_dict[event] = test_ev_type[event];
                    event_dict2[event] = [];
                    // std.out("This work 2");

                    
                    main_queue.list::insert(0,event_dict);
                    answered_queue.list::insert(0,event_dict2);

                    for item in test_ev_type[event]{
                        if (item in main_queue){
                            // std.out('wwww 5');
                            main_queue.list::remove(item);
                        }
                        if (item in visitor.dialogue_context){
                            // if (item in visitor.extracted_entities){
                            // std.out('wwww 2');
                            for i=0 to i<answered_queue.length by i+=1 {
                                if(answered_queue[i].type == dict and item not in answered_queue[i]){
                                    if (event in answered_queue[i]){
                                        answered_queue[i][event].list::append(item);
                                        queue_context[event][item]=visitor.dialogue_context[item];//
                                        delete_entitiy.list::append(item);
                                    }
                                    if (item in answered_queue){
                                        // std.out('wwww 3');
                                        answered_queue.list::remove(item);
                                    }
                                    if (item in queue_context){
                                        // std.out('wwww 4');
                                        queue_context.dict::pop(item);
                                    }
                                    if( item in item_name){
                                        item_name.list::remove(item);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        
        // std.out("main_queuemain_queuemain_queuemain_queuemain_queuemain_queue");
        // std.out(main_queue);
        // std.out(visitor.dialogue_context);
        // std.out("answered_queue");
        // std.out(answered_queue);
        // std.out(queue_context);

        // main_queue list 
        for item in main_queue{
            if (item.type == dict){
                nn = item.dict::keys;
                if (nn[0] not in event_name){
                    event_name.list::append(nn[0]);
                }
            }
            elif (item.type == str){
                if (item not in item_name){
                    item_name.list::append(item);
                }
            }
        }
        // std.out("removed_queue");
        // std.out(removed_queue);

        // update main queue
        if (removed_queue and visitor.respond){ // 
            if(removed_queue not in visitor.dialogue_context){
                if (removed_queue in item_name){
                    if (removed_queue in main_queue){
                        main_queue.list::remove(removed_queue);
                        if(visitor.extracted_entities and removed_queue not in visitor.extracted_entities){
                            visitor.unanswered_queue.list::append(removed_queue);
                        }
                        else{
                            answered_queue.list::append(removed_queue);
                        }
                    }
                }
                else{
                    for ev_name in event_name{
                        for i=0 to i<main_queue.length by i+=1 {
                            if(main_queue[i].type == dict){
                                if (ev_name in main_queue[i]){
                                    // std.out("ev_name");
                                    // std.out(ev_name);
                                    // std.out(ev_type);
                                    // if(ev_name == ev_type){
                                        if (removed_queue in main_queue[i][ev_name] and visitor.respond){
                                            main_queue[i][ev_name].list::remove(removed_queue);
                                            // std.out("test work");
                                            // std.out(i);
                                            // std.out(ev_name);
                                            // std.out("visitor.respond");
                                            // std.out(visitor.respond);
                                            // std.out(removed_queue);
                                            // visitor.unanswered_queue[i][ev_name].list::append(removed_queue);
                                            // visitor.unanswered_queue[i].list::append[ev_name].list::append(removed_queue);
                                            // unanswer_names = [];
                                            // for unanswer in visitor.unanswered_queue{
                                            //     unanswer_names.list::append(unanswer.dict::keys[0]);
                                            // }
                                            // for unanswer_name in unanswer_names{
                                            //     if (unanswer_name in visitor.unanswered_queue){

                                            //     }
                                            // }
                                            // std.out("visitor.unanswered_queue.length");
                                            // std.out(visitor.unanswered_queue.length);
                                            // std.out("visitor.unanswered_queue");
                                            // std.out(visitor.unanswered_queue);
                                            // std.out(removed_queue);
                                            // std.out(ev_name);
                                            // std.out(i);
                                            if (visitor.unanswered_queue.length > i and visitor.unanswered_queue.length <= i){
                                                // std.out("fisrt");
                                                if(visitor.extracted_entities and removed_queue not in visitor.extracted_entities){
                                                    if(ev_name in visitor.answered_queue[i]){
                                                        visitor.unanswered_queue[i][ev_name].list::append(removed_queue);
                                                    }
                                                }else{
                                                    answered_queue[i][ev_name].list::append(removed_queue);
                                                }
                                            }
                                            elif (visitor.unanswered_queue.length <= i){
                                                // std.out("second");
                                                data={};
                                                data[ev_name]=[removed_queue];
                                                if(visitor.extracted_entities and removed_queue not in visitor.extracted_entities){
                                                    visitor.unanswered_queue.list::insert(i, data);
                                                }
                                                else{
                                                    for ans in answered_queue{
                                                        // std.out("ans\n\n\\n");
                                                        // std.out(ans);
                                                        if(ev_name in ans.dict::keys){
                                                            ans[ev_name].list::append(removed_queue);
                                                        }
                                                        else{
                                                            std.out("do somethingsssss \n\n\n\\n\n\n\n\n");
                                                        }
                                                    }
                                                }
                                            }
                                            // if (i not in visitor.unanswered_queue){
                                            //     std.out("removed_queue");
                                            //     std.out(removed_queue);
                                                
                                            //     visitor.unanswered_queue.list::append(data);
                                            // }
                                            // elif(i in visitor.unanswered_queue){
                                            //     if (removed_queue not in visitor.unanswered_queue[i][ev_name]){
                                            //         visitor.unanswered_queue[i][ev_name].list::append(removed_queue);
                                            //     }
                                            // }
                                        }
                                    // }
                                }
                            }
                            elif(main_queue[i].type == str){
                                if (removed_queue in main_queue[i] and removed_queue not in visitor.extract_entities){
                                    main_queue[i].list::remove(removed_queue);
                                    visitor.unanswered_queue[i].list::append(removed_queue);
                                }
                            }
                        }
                    }
                }
            }
        }

        // if (visitor.unanswered_queue){
        //     if (visitor.unanswered_queue[0] in item_name){
        //         if (visitor.unanswered_queue[0] in main_queue){
        //             main_queue.list::remove(visitor.unanswered_queue[0]);
        //         }
        //     }
        //     else{
        //         for ev_name in event_name{
        //             for i=0 to i<main_queue.length by i+=1 {
        //                 if(main_queue[i].type == dict){
        //                     if (ev_name in main_queue[i]){
        //                         if (visitor.unanswered_queue[0] in main_queue[i][ev_name]){
        //                             main_queue[i][ev_name].list::remove(visitor.unanswered_queue[0]);
        //                         }
        //                     }
        //                 }
        //                 elif(main_queue[i].type == str){
        //                     if (visitor.unanswered_queue[0] in main_queue[i]){
        //                         main_queue[i].list::remove(visitor.unanswered_queue[0]);
        //                     }
        //                 }
        //             }
        //         }
        //     }
        // }
        entity_dict = {};
        // std.out("item_name");
        // std.out(item_name);
        // std.out("event_name");
        // std.out(event_name);
        // // std.out("ev_type");
        // // std.out(ev_type);
        // std.out("visitor.dialogue_context");
        // std.out(visitor.dialogue_context);
        // std.out(answered_queue);
        // std.out(visitor.unanswered_queue);
        
        // update answered queue
        for ent in visitor.dialogue_context{
            // std.out(ent);
            if(ent in item_name){
                // std.out("add to answer list");
                // std.out(ent);

                if (ent not in answered_queue and ent in main_queue){
                    answered_queue.list::append(ent);
                    main_queue.list::remove(ent);
                    queue_context[ent] = visitor.dialogue_context[ent]; // new
                    if (ent in visitor.unanswered_queue): visitor.unanswered_queue.list::remove(ent);
                }
                else{
                    // std.out("add to answer list 33");
                    // std.out(ent);
                    for ev_name in event_name{
                        // std.out("ev_name");
                        // std.out(ev_name);
                        // std.out("ev_type");
                        // std.out(ev_type);
                        // for m_ent in main_queue{
                        //     if (m_ent.type == dict){
                        //         // std.out("m_ent");
                        //         // std.out(m_ent);
                        //         if(ent in m_ent.dict::values[0] and m_ent.dict::keys[0] not in ev_type){
                        //             if (m_ent.dict::keys[0] not in ev_type){
                        //                 std.out('this happened 455');
                        //                 ev_type.list::append(m_ent.dict::keys[0]);
                        //             }
                        //         }
                        //     }
                        // }
                        // std.out("ev_type");
                        // std.out(ev_type);

                        // if (ent in main_queue)
                        if (ev_name in ev_type){
                            for i=0 to i<answered_queue.length by i+=1 {
                                if(answered_queue[i].type == dict){
                                    if (ev_name in answered_queue[i]){
                                        // std.out("inside answered_queue");
                                        if(ent not in answered_queue[i][ev_name] and ent in main_queue[i][ev_name]){
                                            answered_queue[i][ev_name].list::append(ent);
                                            delete_entitiy.list::append(ent);
                                            if(ent in queue_context){
                                                queue_context.dict::pop(ent);
                                            }
                                            // std.out(ev_name);
                                            // std.out(ent);
                                            if (visitor.unanswered_queue.length >= i and visitor.unanswered_queue){
                                                if(ev_name in visitor.unanswered_queue[i]){
                                                    if (ent in visitor.unanswered_queue[i][ev_name]): visitor.unanswered_queue[i][ev_name].list::remove(ent);
                                                }
                                            }
                                            // std.out("queue_context 446");
                                            // std.out(visitor.dialogue_context);
                                            // std.out(queue_context);
                                            // entity_dict = {};
                                            entity_dict[ent]=visitor.dialogue_context[ent];

                                            // queue_context[ev_name] = entity_dict;
                                            queue_context[ev_name][ent]=visitor.dialogue_context[ent];
                                            // std.out("queue_context after");
                                            // std.out(queue_context);
                                            // if(ent in queue_context){
                                            //     queue_context.dict::pop(ent);
                                            // }
                                            remove_context.list::append(ent);
                                        }
                                        if(ent in answered_queue){
                                            answered_queue.list::remove(ent);
                                            if (ent in visitor.unanswered_queue): visitor.unanswered_queue.list::remove(ent);
                                        }
                                        if (ent in answered_queue[i][ev_name] and ent in main_queue[i][ev_name]){
                                            main_queue[i][ev_name].list::remove(ent);
                                            // if (ent in visitor.unanswered_queue[i][ev_name]): visitor.unanswered_queue[i][ev_name].list::remove(ent);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // if (ent in main_queue){
                //     main_queue.list::remove(ent);
                // }
            }
            elif(ent not in item_name){
                // std.out("add to dict");
                // std.out(ent);
                for ev_name in event_name{
                    // std.out("ev_name");
                    // std.out(ev_name);
                    // std.out("ev_name");
                    // std.out(ev_name);
                    // std.out("ev_type");
                    // std.out(ev_type);
                    // for m_ent in main_queue{
                    //     if (m_ent.type == dict){
                    //         // std.out("m_ent");
                    //         // std.out(m_ent);
                    //         // if(ent in m_ent.dict::values[0]){
                    //         if(ent in m_ent.dict::values[0] and m_ent.dict::keys[0] not in ev_type){
                                
                    //             if (m_ent.dict::keys[0] not in ev_type){
                    //                 std.out('this happened 433');
                    //                 ev_type.list::append(m_ent.dict::keys[0]);
                    //             }
                    //         }
                    //     }
                    // }
                    // std.out("ev_type");
                    // std.out(ev_type);
                    if (ev_name in ev_type){
                        for i=0 to i<answered_queue.length by i+=1 {
                            if(answered_queue[i].type == dict){
                                if (ev_name in answered_queue[i]){
                                    // std.out("inside answered_queue");
                                    if(ent not in answered_queue[i][ev_name] and ent in main_queue[i][ev_name]){
                                        answered_queue[i][ev_name].list::append(ent);
                                        if(ent in queue_context){
                                            queue_context.dict::pop(ent);
                                        }
                                        // std.out(ev_name);
                                        // std.out(ent);
                                        if (visitor.unanswered_queue.length >= i and visitor.unanswered_queue){
                                            if(ev_name in visitor.unanswered_queue[i]){
                                                if (ent in visitor.unanswered_queue[i][ev_name]): visitor.unanswered_queue[i][ev_name].list::remove(ent);
                                            }
                                        }
                                        // std.out("queue_context 446");
                                        // std.out(visitor.dialogue_context);
                                        // std.out(queue_context);
                                        // entity_dict = {};
                                        entity_dict[ent]=visitor.dialogue_context[ent];

                                        // queue_context[ev_name] = entity_dict;
                                        queue_context[ev_name][ent]=visitor.dialogue_context[ent];
                                        // std.out("queue_context after");
                                        // std.out(queue_context);
                                        // if(ent in queue_context){
                                        //     queue_context.dict::pop(ent);
                                        // }
                                        remove_context.list::append(ent);
                                    }
                                    if(ent in answered_queue){
                                        answered_queue.list::remove(ent);
                                        if (ent in visitor.unanswered_queue): visitor.unanswered_queue.list::remove(ent);
                                    }
                                    // std.out("\nheck yyyyyy");
                                    // std.out(i);
                                    // std.out(ev_name);
                                    if (ent in answered_queue[i][ev_name] and ent in main_queue[i][ev_name]){
                                        // std.out("item removed 782");
                                        main_queue[i][ev_name].list::remove(ent);
                                        // if (ent in visitor.unanswered_queue[i][ev_name]): visitor.unanswered_queue[i][ev_name].list::remove(ent);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // std.out("main_queue bbbbbsbsbs");
        // std.out(main_queue);
        // std.out(answered_queue);

        // update main queue
        for event in event_name{
            for i=0 to i<answered_queue.length by i+=1 {
                if (event in main_queue[i]){
                    for ent in main_queue[i][event]{
                        if (ent in answered_queue[i][event]){
                            // std.out("\n\nthis worked??333");
                            // // std.out(ent);

                            // std.out(event);
                            // std.out(visitor.unanswered_queue);
                            // std.out(visitor.unanswered_queue[i][event]);
                            // std.out(ent);
                            // std.out("main_queue");
                            // std.out(main_queue);
                            main_queue[i][event].list::remove(ent);
                            if (event in visitor.unanswered_queue[i]){
                                if (ent in visitor.unanswered_queue[i][event]): visitor.unanswered_queue[i][event].list::remove(ent);
                            }
                        }
                    }
                }
            }
        }

        // for ent in delete_entitiy{
        //     if(ent in visitor.dialogue_context){
        //         visitor.dialogue_context.dict::pop(ent);
        //     }
        //     delete_entitiy.list::remove(ent);
        // }
    }

    can classify_sentiments{
        // std.out("classify_sentiments");
        // std.out(visitor.respond);
        zs_sentiments_result =  zs_classifier.classify(text=visitor.question, classes=sentiments.dict::keys);
        // std.out("zs_sentiments_result");
        // std.out(zs_sentiments_result);
        zs_sent_list = [];
        zs_sent_maz = 0.75;

        if(visitor.question in zs_sentiments_result[0]){
            visitor.sentiment = "";
            if (zs_sentiments_result[0][visitor.question]){
                for event in zs_sentiments_result[0][visitor.question]{
                    // if (event['confidence'] > 0.75){ 
                    //     sentiment_name = event['value'];
                    //     // visitor.sentiment =rand.choice(sentiments[sentiment_name]);
                        
                    // }
                    if (event['confidence'] > zs_sent_maz){
                        sentiment_name = event['value'];
                        zs_sent_maz = event['confidence'];
                        zs_sent_list = sentiments[sentiment_name];
                    }
                    
                }
            }
            if (zs_sent_list){
                if (queue_context_key){
                    ssss = flow.gen_response(zs_sent_list.list, queue_context[queue_context_key], global.prev_response);
                }
                else{
                    ssss = flow.gen_response(zs_sent_list.list, {}, global.prev_response);
                }
                visitor.sentiment = ssss;
            }
        }

        zs_commentary_result =  zs_classifier.classify(text=visitor.question, classes=commentary_json.dict::keys);
        // std.out("zs_commentary_result");
        // std.out(zs_commentary_result);
        zs_com_maz = 0.75;
        zs_com_list = [];

        if(visitor.question in zs_commentary_result[0]){
            visitor.commentary = "";
            if (zs_commentary_result[0][visitor.question]){
                for event in zs_commentary_result[0][visitor.question]{
                    if (event['confidence'] > zs_com_maz){
                        commentary_name = event['value'];
                        zs_com_maz = event['confidence'];
                        zs_com_list = commentary_json[commentary_name];
                    }
                    
                    // if (event['confidence'] > 0.75){ 
                    //     commentary_name = event['value'];
                    //     std.out(commentary_json[commentary_name]);
                    //     // visitor.commentary =rand.choice(commentary_json[commentary_name]);
                    //     if (queue_context_key){
                    //         ssss = flow.gen_response(commentary_json[commentary_name].list, queue_context[queue_context_key], global.prev_response);
                    //     }
                    //     else{
                    //         ssss = flow.gen_response(commentary_json[commentary_name].list, {}, global.prev_response);
                    //     }
                    //     visitor.commentary = ssss;
                    // }
                }
            }
            if(zs_com_list){
                if (queue_context_key){
                    ssss = flow.gen_response(zs_com_list.list, queue_context[queue_context_key], global.prev_response);
                }
                else{
                    ssss = flow.gen_response(zs_com_list.list, {}, global.prev_response);
                }
                visitor.commentary = ssss;
            }
        }
        // std.out("check thisnowssss \n");
        
        


    }
    
    can nlu with talk entry {
        // std.out("nlu");
        // std.out(visitor.respond);
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        // if(visitor.respond){
        ::update_queue;
        ::classify_sentiments;
        // }

        answered_queue_list = [];
        max_score = 0.01;
        entity_response = [];
        chosen_response= "";
        queue_context_filter = "";
        // queue_context_key = "";
        create_response = "";

        // create answer list from user response
        if(!visitor.respond){ 
            // visitor.answer_list.list::append(visitor.question);
            if "answer_list" not in visitor.dialogue_context{
                visitor.dialogue_context["answer_list"]=[visitor.question];
            }
            else{
                visitor.dialogue_context["answer_list"].list::append(visitor.question);
            }
            // std.out("sentiment: "+ sentiment.str);
        }

        // update extracted_sentences
        // std.out("\n\nvisitor.question");
        // std.out(visitor.question);
        // std.out(visitor.question.str.length);
        // if (visitor.question.length > 3.int){
        //     std.out("it workkkkkkkk");
        // }
        // if(!visitor.predicted_intent){
        // if(visitor.extracted_entities and !visitor.predicted_intent){
            // if (visitor.question.length > 3){   /// fix
        que_list = visitor.question.list;
        if(!visitor.predicted_intent and que_list.length > 3){
            if(first_response){
                visitor.dialogue_context["extracted_sentences"]=[visitor.question];
                first_response = false;
            }
            elif(visitor.question not in visitor.dialogue_context["extracted_sentences"]){
                visitor.dialogue_context["extracted_sentences"].list::append(visitor.question);
            }
            // }
        }
        // else(!visitor.predicted_intent){

        // }

        // update answered_queue_list
        for item in answered_queue{
            if (item.type == dict){
                lis = item.dict::values;
                for entity in lis[0]{
                    answered_queue_list.list::append(entity);
                }
            }
            else{
                answered_queue_list.list::append(item);
            }
        }
        answered_queue_name= "";

        // select entity response 
        for item in main_queue{
            if (item.type == dict){
                item_list = item.dict::values;
                for entity in item_list[0]{
                    // std.out("entity");
                    // std.out(entity);
                    res_list = response_entity['response'].dict::keys;
                    if( entity in res_list){
                        lis = [];
                        for ent in response_entity['response'][entity].dict::keys{
                            if(ent in answered_queue_list){
                                // create list of response from selected entity
                                ans_name = "";
                                for answer in answered_queue{
                                    if (item.dict::keys[0] in answer){
                                        if(ent in answer[item.dict::keys[0]]){
                                            for res in response_entity['response'][entity][ent]{
                                                lis.list::append(res);
                                                ans_name = answer.dict::keys[0];
                                                // std.out("answeransweransweranswer");
                                                // std.out(answer);
                                            }
                                        }
                                    }
                                }
                                if (lis){
                                    ii = 0;
                                    while (max_score < 0.1){
                                        best_answer = use.qa_classify(
                                            text = visitor.dialogue_context["answer_list"][ii],
                                            classes = lis
                                        );
                                        nn = best_answer['match_idx'];

                                        if (best_answer['scores'][nn] > max_score){
                                            max_score = best_answer['scores'][nn];
                                            entity_response = response_entity['response'][entity][ent];
                                            removed_queue = entity;
                                            queue_context_filter = ent;
                                            queue_context_key = item.dict::keys[0];
                                            answered_queue_name = ans_name;
                                        }

                                        leng = visitor.dialogue_context["answer_list"].length - 1;
                                        if (max_score < 0.1){
                                            ii +=1;
                                            if(ii >= leng){
                                                break;
                                            }
                                        }
                                    }
                                    chosen_response= rand.choice(entity_response);
                                }
                            }
                        }
                    }
                }
            }
            elif (item.type == str){
                // std.out("item is string");
                lis = [];
                // std.out(response_entity['response'].dict::keys);
                // std.out(item);
                if (item in response_entity['response'].dict::keys){
                    // if ("default" in response_entity['response'][item].dict::keys){
                    //     chosen_response_list = response_entity['response'][item]['default'];
                    //     removed_queue = item;
                    //     chosen_response = rand.choice(chosen_response_list);
                    //     break; 
                    // }
                    // std.out("inside iffff\n");
                    for ent in response_entity['response'][item].dict::keys{
                        // std.out(answered_queue_list);
                        // std.out(ent);
                        if(ent in answered_queue_list){
                            // create list of response from selected entity
                            // for answer in answered_queue{
                            //     if (ent in answer){
                            //         if(ent in answer[item.dict::keys[0]]){
                            //             for res in response_entity['response'][entity][ent]{
                            //                 lis.list::append(res);
                            //             }
                            //         }
                            //     }
                            //     else
                            // }
                            if(ent in answered_queue){
                                for res in response_entity['response'][item][ent]{
                                    lis.list::append(res);
                                }
                            }
                            // std.out("lis");
                            // std.out(lis);
                            if (lis){
                                ii = 0;
                                while (max_score < 0.1){
                                    best_answer = use.qa_classify(
                                        text = visitor.dialogue_context["answer_list"][ii],
                                        classes = lis
                                    );
                                    nn = best_answer['match_idx'];

                                    if (best_answer['scores'][nn] > max_score){
                                        max_score = best_answer['scores'][nn];
                                        entity_response = response_entity['response'][item][ent];
                                        removed_queue = item;
                                        queue_context_filter = ent;
                                        // queue_context_key= item;
                                    }

                                    leng = visitor.dialogue_context["answer_list"].length - 1;
                                    if (max_score < 0.1){
                                        ii +=1;
                                        if(ii >= leng){
                                            break;
                                        }
                                    }
                                }
                                chosen_response= rand.choice(entity_response);
                            }
                        }
                        if(ent not in answered_queue_list){
                            for res in response_entity['response'][item]["default"]{
                                lis.list::append(res);
                            }
                            // std.out("lis");
                            // std.out(lis);
                            
                            if (lis){
                                ii = 0;
                                while (max_score < 0.1){
                                    // std.out("visitor.answer_listvvvvvvvvv\n");
                                    // std.out(ii);
                                    // std.out(visitor.dialogue_context["answer_list"]);
                                    best_answer = use.qa_classify(
                                        text = visitor.dialogue_context["answer_list"][ii],
                                        classes = lis
                                    );
                                    nn = best_answer['match_idx'];

                                    if (best_answer['scores'][nn] > max_score){
                                        max_score = best_answer['scores'][nn];
                                        entity_response = response_entity['response'][item]["default"];
                                        removed_queue = item;
                                        queue_context_filter = "default";
                                        // queue_context_key= item;
                                    }

                                    leng = visitor.dialogue_context["answer_list"].length - 1;
                                    if (max_score < 0.1){
                                        ii +=1;
                                        if(ii >= leng){
                                            break;
                                        }
                                    }
                                }
                                // chosen_response= rand.choice(entity_response);
                            }
                        }
                    }
                }
            }
        }

        // std.out("queue_context_filter");
        // std.out(queue_context_filter);
        // create_response
        // std.out("queue_contextqueue_contextqueue_contextqueue_contextqueue_context\n");
        // std.out(queue_context);
        // std.out(queue_context_key);
        // std.out(removed_queue);

        // if(queue_context){
        //     ent_que = [];
        //     for item in queue_context{
        //         if(item.type == dict){
        //             ent_que.list::append(item.dict::values[0]);
        //         }
        //     }
        //     // if(removed_queue in ent_que){
        //     //     visitor.predicted_intent2 = "confirm_entity";
        //     // }
        // }
        // std.out("\nqueue_context");
        // std.out(queue_context);
        // std.out(queue_context_filter);
        // std.out(visitor.respond);

        if(queue_context and queue_context_filter != "default" and !visitor.respond){
            // std.out("this if selected 11");
            // for dic in queue_context{
            //     // if(dic)
            //     // std.out("dic do check\n");
            //     // std.out(dic);
            //     // std.out(answered_queue_name);
            //     // std.out(queue_context_key);
            //     // std.out(chosen_response);
            //     if (queue_context_key == dic){
            //         // std.out(queue_context_key);
            //         std.out("queue_context check 1");
            //         std.out(queue_context[dic]);
            //         // std.out(dic);
            //         std.out("chosen_response");
            //         std.out(chosen_response);
            //         create_response = flow.gen_response(chosen_response.str, queue_context[dic]);
            //     }
            //     else{
            //         create_response = flow.gen_response(chosen_response.str, queue_context);
            //     }
            // }

            // main_que = [];
            // for m_items in main_queue{
            //     if(m_items.type == dict){
            //         for m_item in m_items.dict::values[0]{
            //             if(m_item not in main_que): main_que.list::append(m_item);
            //         }
            //     }
            // }
            
            // confirm_entity_json = file.load_json("utils/data/comfirm_entity.json");
            // ent_que = [];
            // select_que ="";
            // ans_que_cont = {};
            // std.out("removed_queueremoved_queueremoved_queueremoved_queue");
            // std.out(removed_queue);
            // std.out(queue_context_key);
            // std.out(queue_context_filter);
            // for items in queue_context{
            //     std.out("items");
            //     std.out(items);
            //     if(queue_context[items].type == dict){
            //         if(removed_queue in queue_context[items]){
            //             select_que = items;
            //         }
            //         for item in queue_context[items]{
            //             if (item not in ent_que): ent_que.list::append(item);
            //             if (item not in ans_que_cont and items == select_que): ans_que_cont[item]=queue_context[items][item];
            //             elif (item not in ans_que_cont and item in main_que): ans_que_cont[item]=queue_context[items][item];
            //             // elif( item in main_queue[items] and removed_queue in queue_context[items][item]):ans_que_cont[item]=queue_context[items][item];
            //             // elif( item in ans_que_cont and removed_queue in queue_context[items][item]):ans_que_cont[item]=queue_context[items][item];
            //         }
            //         // if (removed_queue in item.dict::values[0]){
            //         //     for sentence in confirm_entity_json[removed_queue]{
            //         //         flow.select_ent_response(sentence, queue_context[queue_context_key])
            //         //     }
            //         // }
            //     }
            // }
            
            // // std.out("removed_queue");
            // // std.out(removed_queue);
            // // std.out(queue_context_key);
            // // std.out("queue_context_filter");
            // // std.out(queue_context_filter);
            // // std.out(ent_que);
            // // std.out("select_que");
            // // std.out(select_que);
            // // std.out(ans_que_cont);
            // std.out("main_que");
            // std.out(main_que);
            // if(removed_queue in ent_que and removed_queue in main_que){
            //     // std.out("this if selected 00");
            //     // visitor.predicted_intent2 = "confirm_entity";
            //     std.out("ans_que_cont");
            //     std.out(ans_que_cont);
            //     std.out(removed_queue);
            //     std.out(queue_context_key);
            //     response_list = [];
            //     for sentence in confirm_entity_json[removed_queue]{
            //         // placeholders = [placeholder.strip(" {}") for placeholder in sentence.split("{{") if "}}" in placeholder];
            //         // for ent in placeholders{
            //         //     if(ent not in queue_context[queue_context_key]){
            //         //         break;
            //         //     }
            //         // }
                    
            //         res = flow.select_ent_response(sentence, ans_que_cont);
            //         response_list.list::append(res);
            //         std.out("check response 4333");
            //         std.out(create_response);
            //     }
            //     std.out("response_list");
            //     std.out(response_list);
            //     if (response_list and ans_que_cont): create_response = flow.gen_response(response_list.list, ans_que_cont, global.prev_response);
            //     // create_response = flow.gen_response(response_list.list, queue_context[select_que]);

            // }
            if (queue_context_key in queue_context and entity_response){
                // std.out("this if selected 44");
                // std.out(entity_response);
                // std.out(queue_context_key);
                create_response = flow.gen_response(entity_response.list, queue_context[queue_context_key], global.prev_response);
            }
            elif(entity_response and queue_context){
                // std.out("this if selected 55");
                create_response = flow.gen_response(entity_response.list, queue_context, global.prev_response);
            }
        }
        elif(entity_response){
            // std.out("this if selected 33");
            // std.out("check else");
            // std.out(chosen_response);
            // create_response = flow.gen_response(entity_response.list);
            // create_response = entity_response;
            create_response = flow.gen_response(entity_response.list, {}, global.prev_response);
            // create_response = chosen_response;
        }

        // add sentiment to response
        // std.out("removed_queue");
        // std.out(removed_queue);
        // std.out(default_queue);
        // if (visitor.sentiment != "" and removed_queue and removed_queue not in default_queue){
        if (visitor.sentiment != "" or visitor.commentary !=""){
            // std.out("THis ran commentary and sentiment");
            // std.out(visitor.sentiment);
            // std.out(visitor.commentary);
            // std.out(create_response);
            new = visitor.sentiment.str + " " + visitor.commentary.str + " " + create_response.str;
            visitor.response = new;
        }
        else{
            visitor.response = create_response;
        }
        // visitor.response = visitor.sentiment.str + " " + create_response.str;

        // remove entity form visitor.dialogue_context
        for entity in remove_context{
            if (entity in visitor.dialogue_context): visitor.dialogue_context.dict::pop(entity);
            remove_context.list::remove(entity);
        }

        if (!visitor.respond){
            std.out("FIRST");
            std.out("queue_context");
            std.out(queue_context);
            std.out("\nmain_queue");
            std.out(main_queue);
            std.out("answered_queue");
            std.out(answered_queue);
            std.out("visitor.unanswered_queue");
            std.out(visitor.unanswered_queue);

            visitor.dialogue_context["queue_context"] = queue_context;
        }

        if (visitor.response) {
            visitor.next_state = here;
            // std.out("NOTE_:: response\n\n");
        }
        elif!(visitor.response){
            
            std.out("SECOND");
            std.out("queue_context");
            std.out(queue_context);
            std.out("\n main_queue ");
            std.out(main_queue);
            std.out("answered_queue");
            std.out(answered_queue);
            std.out("visitor.unanswered_queue");
            std.out(visitor.unanswered_queue);

            visitor.dialogue_context['queue_context'] = queue_context;
            for item in visitor.dialogue_context['queue_context']{
                if(visitor.dialogue_context['queue_context'][item].type==dict){
                    if(item in queue_context){
                        for ent in queue_context[item]{
                            if (ent not in visitor.dialogue_context['queue_context'][item]){
                                visitor.dialogue_context['queue_context'][item][ent] = queue_context[item][ent];
                            }
                        }
                    }
                }
                elif(visitor.dialogue_context['queue_context'][item].type==list){
                    if (item not in visitor.dialogue_context['queue_context']){
                        visitor.dialogue_context['queue_context'][item]=queue_context[item];
                    }
                }
            }

            // visitor.dialogue_context["queue_context"] = queue_context;

            // fix 
            // for items in queue_context{
            //     // std.out("items label\n");
            //     // std.out(items);
            //     if(queue_context[items].type == dict){
            //         std.out("dict check 11");
            //         std.out(item);
            //         std.out(visitor.dialogue_context['queue_context']);

            //         if(items not in visitor.dialogue_context['queue_context']){
            //             std.out("items label\n");
            //             std.out(items);
            //             visitor.dialogue_context['queue_context'][items] = queue_context[items];
            //         }

            //     }
            //     elif(queue_context[items].type == list){
            //         if(items not in visitor.dialogue_context['queue_context']){
            //             std.out("items label\n");
            //             std.out(items);
            //             visitor.dialogue_context['queue_context'][items] = queue_context[items];
            //         }
            //     }
            // }


            // std.out("visitor.dialogue_context que check\n");
            // std.out(visitor.dialogue_context);

            // std.out("NOTE_:: no response\n\n");
            // std.out("visitor.unanswered_queue.length");
            // std.out(visitor.unanswered_queue.length);
            // unans_bool = false;
            if (main_queue){
                for ent in main_queue{
                    // std.out("ent");
                    // std.out(ent);
                    // std.out(ent.dict::values.length);
                    if (ent.type == dict){
                        
                        if (visitor.unanswered_queue and ent.dict::values.length == 0){
                            // unans_bool = true;
                            // std.out("bool embpt");
                            visitor.predicted_intent2 = "unanswered_queue";
                        }
                    }
                }
            }
            elif(!main_queue){
                // std.out("unas work");
                visitor.predicted_intent2 = "unanswered_queue";
            }
            // if (visitor.unanswered_queue){
            //     std.out("unasn check 32");
            //     visitor.predicted_intent2 = "unanswered_queue";
            // }
            visitor.respond = true;
            visitor.next_state = null;
        }
        else: {
            std.out("NOTE_:: Else event ran\n\n");
        }
    }
}


node soc:dialogue_state{
    has name;

    can nlu with talk entry {
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        state_json = file.load_json(global.train_state_path);
        for state in state_json{
            if (!visitor.respond) {
                if (here.name == state["name"].str){
                    arry = flow.select_response({}, state['responses'], {});
                    visitor.response = arry['response'];
                }
            }
        }
    }
}


node eoc:dialogue_state{
    has name;

    can nlu with talk entry {
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        state_json = file.load_json(global.train_state_path);
        for state in state_json{
            if (!visitor.respond) {
                if (here.name == state["name"].str){
                    arry = flow.select_response({}, state['responses'], {});
                    visitor.response = arry['response'];
                }
            }
        }
    }
}


// node save_memory:dialogue_state{
//     has name;

//     can nlu with talk entry {
//         ::classify_intent;
//         ::extract_entities;
//         ::business_logic;

//         state_json = file.load_json(global.train_state_path);
//         for state in state_json{
//             if (!visitor.respond) {
//                 if (here.name == state["name"].str){
//                     arry = flow.select_response({}, state['responses'], {});
//                     visitor.response = arry['response'];
//                 }
//             }
//         }
//     }
// }


// node confirm_save_memory:dialogue_state{
//     has name;

//     can nlu with talk entry {
//         ::classify_intent;
//         ::extract_entities;
//         ::business_logic;

//         state_json = file.load_json(global.train_state_path);
//         for state in state_json{
//             if (!visitor.respond) {
//                 if (here.name == state["name"].str){
//                     arry = flow.select_response({}, state['responses'], {});
//                     visitor.response = arry['response'];
//                 }
//             }
//         }
//     }
// }


// node confirm_cancel_memory:dialogue_state{
//     has name;

//     can nlu with talk entry {
//         ::classify_intent;
//         ::extract_entities;
//         ::business_logic;

//         state_json = file.load_json(global.train_state_path);
//         for state in state_json{
//             if (!visitor.respond) {
//                 if (here.name == state["name"].str){
//                     arry = flow.select_response({}, state['responses'], {});
//                     visitor.response = arry['response'];
//                 }
//             }
//         }
//     }
// }


node cancel_memory:dialogue_state{
    has name;

    can nlu with talk entry {
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        state_json = file.load_json(global.train_state_path);
        for state in state_json{
            if (!visitor.respond) {
                if (here.name == state["name"].str){
                    arry = flow.select_response({}, state['responses'], {});
                    visitor.response = arry['response'];
                }
            }
        }
    }
}


node document_memory:dialogue_state{
    has name;

    can nlu with talk entry {
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        state_json = file.load_json(global.train_state_path);
        for state in state_json{
            if (!visitor.respond) {
                if (here.name == state["name"].str){
                    // arry = flow.select_response({}, state['responses'], {});
                    // visitor.response = arry['response'];
                    visitor.dialogue_context["user_name"]="Tharick";
                    visitor.response = flow.gen_response(state['responses'], visitor.dialogue_context, global.prev_response);
                }
            }
        }
    }
}


node additional_memory:dialogue_state{
    has name;

    can nlu with talk entry {
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        state_json = file.load_json(global.train_state_path);
        for state in state_json{
            if (!visitor.respond) {
                if (here.name == state["name"].str){
                    arry = flow.select_response({}, state['responses'], {});
                    visitor.response = arry['response'];
                }
            }
        }
    }
}


node unanswered_queue:dialogue_state{
    has name;
    has response_entity = file.load_json("utils/data/queue.json");
    has removed_queue;

    can update_removed_que{
        // std.out("removed_queue");
        // std.out(removed_queue);
        if (visitor.respond){
            // std.out("visitor.unanswered_queue");
            // std.out(visitor.unanswered_queue);
            // std.out(removed_queue);
            if(removed_queue){
                for item in visitor.unanswered_queue{
                    if (item.type == dict){
                        // std.out("item");
                        // std.out(item);
                        for ent in item{
                            // std.out("this was removed");
                            // std.out(ent);
                            if( removed_queue in item[ent]){
                                item[ent].list::remove(removed_queue);
                            }
                        }
                    }
                    elif(item.type == str and removed_queue in visitor.unanswered_queue){
                        visitor.unanswered_queue.list::remove(removed_queue);
                    }
                }
            }
        }
    }

    can update_queue{
        if(visitor.extracted_entities){
            for entities in visitor.extracted_entities{
                // std.out("entities outside");
                // std.out(entities);
                for item in visitor.unanswered_queue{
                    if (item.type == dict){
                        // std.out("item outside");
                        // std.out(item);
                        // std.out(item.dict::values[0]);
                        if (entities in item.dict::values[0]){
                            // std.out("entities inside");
                            // std.out(entities);
                            // std.out(item.dict::keys[0]);
                            if(item.dict::keys[0] in visitor.dialogue_context['queue_context']){
                                visitor.dialogue_context['queue_context'][item.dict::keys[0]][entities]= visitor.extracted_entities[entities];
                            }

                            for item in visitor.unanswered_queue{
                                // std.out("item");
                                // std.out(item);
                                for ent in item{
                                    // std.out("this was removed");
                                    // std.out(ent);
                                    if( entities in item[ent]){
                                        item[ent].list::remove(entities);
                                    }
                                }
                            }
                        }
                    }
                    elif (item.type == str){
                        if (item in visitor.unanswered_queue and item in visitor.extracted_entities){
                            visitor.dialogue_context['queue_context'][item]=visitor.extracted_entities[item];
                            visitor.unanswered_queue.list::remove(item);
                        }
                    }
                }
            }
        }
    }


    can nlu with talk entry {
        ::classify_intent;
        ::extract_entities;
        ::business_logic;

        ::update_queue;
        ::update_removed_que;

        state_response = "";

        answered_queue_list = [];
        max_score = 0;
        entity_response = [];
        chosen_response= "";
        queue_context_filter = "";
        queue_context_key = "";
        create_response = "";
        chosen_response_list = [];

        que_list = visitor.question.list;
        if(!visitor.predicted_intent and que_list.length > 3){
            if("extracted_sentences" not in visitor.dialogue_context){
                visitor.dialogue_context["extracted_sentences"]=[visitor.question];
            }
            elif(visitor.question not in visitor.dialogue_context["extracted_sentences"]){
                visitor.dialogue_context["extracted_sentences"].list::append(visitor.question);
            }
        }

        state_json = file.load_json(global.train_state_path);
        for state in state_json{
            if (!visitor.respond) {
                if (here.name == state["name"].str){
                    arry = flow.select_response({}, state['responses'], {});
                    state_response = arry['response'];
                }
            }
        }


        // std.out("visitor.dialogue_context['queue_context']");
        // std.out(visitor.dialogue_context["queue_context"]);
        for item in visitor.dialogue_context["queue_context"]{
            if(visitor.dialogue_context['queue_context'][item].type==dict){
                for entity in visitor.dialogue_context['queue_context'][item].dict::keys{
                    answered_queue_list.list::append(entity);
                }
            }
            else{
                answered_queue_list.list::append(item);
            }
        }

        // update answered_queue_list
        // for item in answered_queue{
        //     if (item.type == dict){
        //         lis = item.dict::values;
        //         for entity in lis[0]{
        //             answered_queue_list.list::append(entity);
        //         }
        //     }
        //     else{
        //         answered_queue_list.list::append(item);
        //     }
        // }

        for item in visitor.unanswered_queue{
            if (item.type == dict){
                item_list = item.dict::values;
                for entity in item_list[0]{
                    // std.out("entity");
                    // std.out(entity);
                    res_list = response_entity['response'].dict::keys;
                    // std.out("res_list");
                    // std.out(res_list);
                    if( entity in res_list){
                        for ent in response_entity['response'][entity].dict::keys{
                            lis = [];
                            // std.out("ent\n");
                            // std.out(ent);
                            // create list of response from selected entity
                            // std.out("\ntestss");
                            // std.out(item.dict::keys[0]);
                            // std.out(visitor.dialogue_context["queue_context"].dict::keys);
                            for answer in visitor.dialogue_context["queue_context"].dict::keys{
                                if (item.dict::keys[0] == answer){
                                    // std.out("item.dict::keys[0]");
                                    // std.out(item.dict::keys[0]);
                                    // std.out(visitor.dialogue_context["queue_context"][answer].dict::keys);
                                    if(ent in visitor.dialogue_context["queue_context"][answer].dict::keys){
                                        // std.out("ent inside");
                                        // std.out(ent);
                                        for res in response_entity['response'][entity][ent]{
                                            lis.list::append(res);
                                        }
                                    }
                                    elif(ent not in visitor.dialogue_context["queue_context"][answer].dict::keys){
                                        // std.out("default");
                                        if (ent == "default"){
                                            // lis = response_entity['response'][entity]['default'];
                                            for res in response_entity['response'][entity]['default']{
                                                lis.list::append(res);
                                            }
                                        }
                                        // std.out(entity);
                                        // std.out(lis);
                                        // std.out(ent);
                                    }
                                }
                            }
                            // std.out("lis");
                            // std.out(lis);
                            if (lis){

                                best_answer = use.qa_classify(
                                    text = visitor.question,
                                    classes = lis
                                );
                                nn = best_answer['match_idx'];
                                // std.out(max_score);
                                // std.out("best_answer");
                                // std.out(best_answer);
                                // std.out("ent");
                                // std.out(ent);

                                // std.out("response_entity['response'][entity][ent]");
                                // std.out(response_entity['response'][entity][ent]);
                                

                                if (best_answer['scores'][nn] > max_score){
                                    max_score = best_answer['scores'][nn];
                                    entity_response = response_entity['response'][entity][ent];
                                    removed_queue = entity;
                                    queue_context_filter = ent;
                                    queue_context_key= item.dict::keys[0];
                                    // std.out("entent");
                                    // std.out(ent);
                                }

                                // std.out("entity_response");
                                // std.out(entity_response);
                                // chosen_response= rand.choice(entity_response);
                            }
                            

                            if (lis){
                                std.out("in list");
                                ii = 0;
                                while (max_score < 0.0000001){
                                    std.out("in while");
                                    best_answer = use.qa_classify(
                                        text = visitor.question,
                                        classes = lis
                                    );
                                    nn = best_answer['match_idx'];
                                    // std.out(max_score);
                                    // std.out("best_answer");
                                    // std.out(best_answer);

                                    if (best_answer['scores'][nn] > max_score){
                                        max_score = best_answer['scores'][nn];
                                        entity_response = response_entity['response'][entity][ent];
                                        removed_queue = entity;
                                        queue_context_filter = ent;
                                        queue_context_key= item.dict::keys[0];
                                    }

                                    leng = visitor.dialogue_context["answer_list"].length - 1;
                                    if (max_score < 0){
                                        ii +=1;
                                        if(ii >= leng){
                                            break;
                                        }
                                    }
                                }
                                // std.out(max_score);
                                // chosen_response= rand.choice(entity_response);
                                // std.out("chosen_response");
                                // std.out(chosen_response);
                            }
                        }
                    }
                }
                if(entity_response): chosen_response= flow.gen_response(lis.list, visitor.dialogue_context["queue_context"][queue_context_key], global.prev_response);
                // if(entity_response): chosen_response= rand.choice(entity_response);
            }
            // elif (item.type == str){
            //     // std.out("item is string");
            //     if (item in response_entity['response'].dict::keys){
            //         if ("default" in response_entity['response'][item].dict::keys){
            //             chosen_response_list = response_entity['response'][item]['default'];
            //             removed_queue = item;
            //             // chosen_response= rand.choice(chosen_response_list);
            //             // std.out("chosen_response");
            //             // std.out(chosen_response);
            //             // queue_context_filter = "default";
            //             break; 
            //         }
            //     }
            // }

            elif (item.type == str){

                lis = [];

                if (item in response_entity['response'].dict::keys){


                    for ent in response_entity['response'][item].dict::keys{
                        if(ent in answered_queue_list){
                            // // if(ent in answered_queue){
                            for res in response_entity['response'][item][ent]{
                                lis.list::append(res);
                            }
                            // }

                            if (lis){
                                ii = 0;
                                while (max_score < 0.1){
                                    best_answer = use.qa_classify(
                                        text = visitor.dialogue_context["answer_list"][ii],
                                        classes = lis
                                    );
                                    nn = best_answer['match_idx'];

                                    if (best_answer['scores'][nn] > max_score){
                                        max_score = best_answer['scores'][nn];
                                        entity_response = response_entity['response'][item][ent];
                                        removed_queue = item;
                                        queue_context_filter = ent;
                                        // queue_context_key= item;
                                    }

                                    leng = visitor.dialogue_context["answer_list"].length - 1;
                                    if (max_score < 0.1){
                                        ii +=1;
                                        if(ii >= leng){
                                            break;
                                        }
                                    }
                                }
                                // chosen_response= rand.choice(entity_response);
                            }
                            // std.out("lis");
                            // std.out(lis);
                            // chosen_response = rand.choice(lis);
                            chosen_response = flow.gen_response(lis.list, visitor.dialogue_context["queue_context"], global.prev_response);
                        }
                        if(ent not in answered_queue_list){
                            for res in response_entity['response'][item]["default"]{
                                lis.list::append(res);
                            }
                            // std.out("lis");
                            // std.out(lis);
                            if (lis){
                                ii = 0;
                                while (max_score < 0.1){
                                    best_answer = use.qa_classify(
                                        text = visitor.dialogue_context["answer_list"][ii],
                                        classes = lis
                                    );
                                    nn = best_answer['match_idx'];

                                    if (best_answer['scores'][nn] > max_score){
                                        max_score = best_answer['scores'][nn];
                                        entity_response = response_entity['response'][item]["default"];
                                        removed_queue = item;
                                        queue_context_filter = "default";
                                        // queue_context_key= item;
                                    }

                                    leng = visitor.dialogue_context["answer_list"].length - 1;
                                    if (max_score < 0.1){
                                        ii +=1;
                                        if(ii >= leng){
                                            break;
                                        }
                                    }
                                }
                                // chosen_response = flow.gen_response(lis.list, {}, global.prev_response);
                            }
                        }
                    }
                }
                // chosen_response= rand.choice(entity_response);
                // chosen_response_list = lis;
                if (entity_response): chosen_response = flow.gen_response(lis.list, visitor.dialogue_context["queue_context"], global.prev_response);
            }
        }
        // create_response = "";
        // std.out("chosen_response_list");
        // std.out(chosen_response_list);
        // if(visitor.dialogue_context["queue_context"] and queue_context_filter != "default" and chosen_response_list){

        //     for dic in visitor.dialogue_context["queue_context"]{
        //         if (queue_context_key == dic){
        //             create_response = flow.gen_response(chosen_response_list.list, visitor.dialogue_context["queue_context"][dic], global.prev_response);
        //         }
        //         else{
        //             // create_response = chosen_response;
        //             create_response = flow.gen_response(chosen_response_list.list, visitor.dialogue_context["queue_context"], global.prev_response);
        //         }
        //     }

        // }
        // elif!(visitor.dialogue_context["queue_context"] and queue_context_filter !="default"){
        //     // create_response = chosen_response;
        //     chosen_response = flow.gen_response(lis.list, {}, global.prev_response);
        // }

        // if (create_response and state_response){
        //     visitor.response = state_response.str + " " + create_response.str;
        // }
        if (chosen_response and state_response){
            visitor.response = state_response.str + " " + chosen_response.str;
        }

        if(visitor.unanswered_queue){
            for item in visitor.unanswered_queue{
                if (item.type == dict){
                    if (item.dict::values[0].length >=1){
                        visitor.next_state = here;
                    }
                    else{
                        visitor.predicted_intent2 = "additional_memory";
                        visitor.respond = true;
                    }
                }
                elif(item.type == str){
                    visitor.next_state = here;
                }
            }
        }
        elif(!visitor.unanswered_queue){
            visitor.predicted_intent2 = "additional_memory";
            visitor.respond = true;
        }
    }
}


    