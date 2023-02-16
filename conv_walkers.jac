// spawn faq_state 
walker ingest_faq {
    has kb_file;

    root: take -[dialog]-> node::dialog;
    dialog: take -[intent_transition]-> node::faqs;
    faqs {
        kb = file.load_json(global.train_faq_answer_path);
        for faq in kb {
            answer = faq["answer"];
            spawn here +[faq]+> node::faq(name = "faq", answer=answer);

        }
    }
}

// update user node
walker maintainer {
    has prev_state;
    has dialogue_context;
    // has queue_context;
    has unanswered_queue;

    root: take -[user]-> node::user;
}

// talker 
walker talk {
    has question, phone_number;
    has predicted_intent;
    has predicted_intent2;
    has extracted_entities={};
    has dialogue_context ={};

    has response;
    has next_state;
    has prev_state;
    has cont_state;
    has respond = true;
    has threshold = false;

    // tubo //
    has image_urls = null;

    has sentiment = "";
    has unanswered_queue = [];
    // has queue_context = {};
    // tubo //




    root: take -[user]-> node::user;
    user {
        if(cont_state == ""): std.out('WALKER TALKER ERROR: cont_state is an EMPTY STR');
        take *(cont_state);
    }
    dialogue_state {
        if (respond) {
            take next_state else {
                report {
                    "name": here.name,
                    "response": "Sorry I can't handle that just yet."
                };
            }
            respond = false;
        } 
    }
}


walker get_memories{
    has memory={};
    has memory_list = [];
    // has payload = {
    //     "id" :memory.id,
    //     "date_created": memory.date_created,
    //     "date_modified": memory.date_modified,
    //     "subject" : memory.subject,
    //     "category" :memory.category,
    //     "summary" : memory.summary,
    //     "description" : memory.description,
    //     "what" : memory.what,
    //     "who" : memory.who,
    //     "where" :memory.where,
    //     "how" : memory.how,
    //     "when" : memory.when,
    //     "file_ids" :memory.file_ids,
    //     "image_urls":memory.image_urls
    // };

    root: take -[memories]-> node::memories else{
        report:custom = "no memories found";
    }
    memories: take -[memory]-> node::memory;
    memory{
        
        payload={};
        payload["category"]="";
        payload["date_created"]=here.date_created;
        payload["date_modified"]=here.date_modified;
        payload["description"]=here.description;
        payload["how"]=here.how;
        payload["id"]=here.id;
        payload["image_urls"]=[here.image_urls];
        payload["relatedMemories"]=here.relatedMemories;
        payload["subject"]=here.subject;
        payload["summary"]=here.summary;
        payload["when"]=here.when;
        payload["where"]=here.where;
        payload["who"]=here.who;

        memory_list.list::append(payload);
        // memory_list.list::append(here.context);
    }
    with exit{
        report memory_list;

    }

}

walker get_memory {
    has id;
    has payload={};
    has memory_list = [];

    root: take -[memories]-> node::memories else{
        report:custom = "no memories found";
    }
    memories: take -[memory(id==id)]-> node::memory;
    memory{
        // payload={};
        payload["category"]="";
        payload["date_created"]=here.date_created;
        payload["date_modified"]=here.date_modified;
        payload["description"]=here.description;
        payload["how"]=here.how;
        payload["id"]=here.id;
        payload["image_urls"]=[here.image_urls];
        payload["relatedMemories"]=here.relatedMemories;
        payload["subject"]=here.subject;
        payload["summary"]=here.summary;
        payload["when"]=here.when;
        payload["where"]=here.where;
        payload["who"]=here.who;

        // memory_list.list::append(payload);
        // memory_list.list::append(here.context);
    }
    with exit{
        report payload;
        // report memory_list;

    }
} 

walker create_memory{
    has memory_context;
    has image_urls;
    has subject_title;
    has sentiments = file.load_json("utils/data/summary/sentiments.json");
    has gs_description;

    can tobu.phrase_to_date;

    root: take -[memories]-> node::memories else{
        spawn here +[memories]+> node::memories;
        take -[memories]-> node::memories;
    }
    memories{
        payload ={};
        if(memory_context){
            // std.out("\nmemory_context");
            // std.out(memory_context);

            memory_id = rand.word() + (rand.integer(0, 99999)).str;

            for item in memory_context['queue_context']{
                if(memory_context['queue_context'][item].type == dict){
                    if('date' in memory_context['queue_context'][item]){
                        payload["when"] = tobu.phrase_to_date(memory_context['queue_context'][item]['date'][0]);
                    }
                    // if('subject' in memory_context['queue_context'][item]){
                    //     payload["subject"] = memory_context['queue_context'][item]['subject'];
                    // }
                    if('emotion' in memory_context['queue_context'][item]){
                        em = memory_context['queue_context'][item]['emotion'][0];
                        best_answer = use.text_classify(
                            text = em,
                            classes = sentiments.dict::keys
                        );
                        // std.out("best_answer");
                        // std.out(best_answer);
                        payload["how"] = best_answer.match;
                        // std.out("memory_context['queue_context']['emotion']");
                        // std.out(memory_context['queue_context']['emotion']);
                        // std.out("em");
                        // std.out(em);
                        // zs_result =  zs_classifier.classify(text=em, classes=sentiments.dict::keys);
                        // zs_emotion = "";
                        // if(em in zs_result[0]){
                        //     if (zs_result[0][em]){
                        //         // for event in zs_result[0][em]{
                        //         //     if (event['confidence'] > 0.75){ 
                        //         //         sentiment_name = event['value'];
                        //         //         visitor.sentiment =rand.choice(sentiments[sentiment_name]);
                        //         //     }
                        //         // }
                        //         std.out("zs_result[0][em]");
                        //         std.out(zs_result[0][em]);
                        //         zs_emotion = zs_result[0][em][0]['value'];
                        //     }
                        // }
                        // payload["how"] = zs_emotion;
                    }
                    if('location' in memory_context['queue_context'][item]){
                        payload["where"] = memory_context['queue_context'][item]['location'][0];
                    }
                    if('people' in memory_context['queue_context'][item]){
                        payload["who"] = memory_context['queue_context'][item]['people'];
                    }
                }
                elif(memory_context['queue_context'][item].type == list){
                    if('date' in memory_context['queue_context']){
                        payload["when"] = tobu.phrase_to_date(memory_context['queue_context']['date'][0]);
                    }
                    // if('subject' in memory_context['queue_context']){
                    //     payload["subject"] = "memory_context['queue_context']['subject']";
                    // }
                    if('emotion' in memory_context['queue_context']){
                        em = memory_context['queue_context']['emotion'][0];
                        // std.out("memory_context['queue_context']['emotion']");
                        // std.out(memory_context['queue_context']['emotion']);
                        // std.out("em");
                        // std.out(em);
                        // std.out(sentiments.dict::keys);

                        best_answer = use.text_classify(
                            text = em,
                            classes = sentiments.dict::keys
                        );
                        // std.out("best_answer");
                        // std.out(best_answer);
                        payload["how"] = best_answer.match;
                        
                        // zs_result =  zs_classifier.classify(text=em, classes=sentiments.dict::keys);
                        // // zs_result =  zs_classifier.classify(text=em, classes=sentiments.dict::keys);
                        // zs_emotion = "";
                        // std.out("zs_result");
                        // std.out(zs_result);
                        // if(em in zs_result[0]){
                        //     if (zs_result[0][em]){
                        //         // for event in zs_result[0][em]{
                        //         //     if (event['confidence'] > 0.75){ 
                        //         //         sentiment_name = event['value'];
                        //         //         visitor.sentiment =rand.choice(sentiments[sentiment_name]);
                        //         //     }
                        //         // }
                        //         std.out("zs_result[0][em]");
                        //         std.out(zs_result[0][em]);
                        //         zs_emotion = zs_result[0][em][0]['value'];
                        //     }
                        // }
                        // payload["how"] = zs_emotion;
                        
                        // payload["how"] = memory_context['queue_context']['emotion'][0];
                    }
                    if('location' in memory_context['queue_context']){
                        payload["where"] = memory_context['queue_context']['location'][0];
                    }
                    if('people' in memory_context['queue_context']){
                        payload["who"] = memory_context['queue_context']['people'];
                    }
                    // if('date' in )
                }
            }
            // if("date" in memory_context[queue_context])
            // date_created = memory_context['date']);
            payload["date_modified"] = date.datetime_now();
            payload["date_created"] = date.datetime_now();
            payload["id"]= memory_id;
            payload['summary'] = memory_context['summary'];
            
            payload['category'] = "";
            payload["subject"] = subject_title;
            payload["file_ids"] = "";
            payload["description"] = gs_description;
            payload["relatedMemories"] = [];
            
            
            std.out("\n\npayload");
            std.out(payload);
            if(image_urls){
                payload['image_urls'] = image_urls[0];
                nd = spawn node::memory(id=payload.id, subject=payload.subject, category=payload.category, summary=payload.summary, description=payload.description, when= payload.when, how=payload.how, who=payload.who, where=payload.where, file_ids=payload.file_ids, date_created = payload.date_created, date_modified= payload.date_modified, image_urls=payload.image_urls, relatedMemories=payload.relatedMemories);
                here +[memory(id=payload.id)]+> nd;
                // std.out("nd.info['context']");
                // std.out(nd.info['context']);
            }
            else{
                // std.out("no image url");
                nd = spawn node::memory(id=payload.id, subject=payload.subject, category=payload.category, summary=payload.summary, description=payload.description, when= payload.when, how=payload.how, who=payload.who, where=payload.where, file_ids=payload.file_ids, date_created = payload.date_created, date_modified= payload.date_modified, relatedMemories=payload.relatedMemories);
                here +[memory(id=payload.id)]+> nd;
            }
            // std.out(payload);
            // std.out(payload.id);
        }

    }


    // {"date": ["morning"], "extracted_sentences": ["I went for a run this morning", "I did my run in the national park. The weather was mucky and the sky was grey but i still had a very good run.", "It was a great run. i did 2 mile. I felt refresh.", "yes. I ran into a old school friend. we haven't seen each other in a decade. Her name is Rebecca."], "queue_context": {"date": ["morning"], "location": ["national park"], "emotion": ["great"]}, "location": ["national park"], "emotion": ["great"], "people": ["rebecca"], "summary": "I went for a run this morning. The weather was mucky and the sky was grey but I still had a very good run. I did 2 miles. I felt refreshed. yes. I ran into an old school friend. we haven't seen each other in a decade. Her name is Rebecca."}

}

walker update_memory {
    has id;
    has subject;
    has category; 
    has summary;
    has description;
    has when;
    has what;
    has how;
    has who;
    has where;
    has file_ids;
    has image_urls;

    has date_created;
    has date_modified;

    has everyone = [];

    root: take -[memories]-> node::memories else{
        report:custom = "no memories found";
    }
    memories: take -[memory(id==id)]-> node::memory;
    memory{
        here.date_modified = date.datetime_now();

        if(date_created): here.date_created = date_created;
        if(subject): here.subject = subject;
        if(category): here.category = category;
        if(summary): here.summary = summary;
        if(description): here.description = description;
        if(when): here.when = when;
        if(what): here.what = what;
        if(how): here.how = how;
        
        if(where): here.where = where;
        if(file_ids): here.file_ids = file_ids;
        if(image_urls):here.image_urls = image_urls;
    }

}

walker delete_memory {
    has id;
    root: take -[memories]-> node::memories else{
        report:custom = "no memories found";
    }
    memories: take -[memory(id==id)]-> node::memory;
    memory {
        report here;
        destroy here;
        disengage;
    }
}

edge memories;
edge memory: has id;

node memories;
node memory {
    has id;
    has subject;
    has category; 
    has summary;
    has description;
    has when;
    has what;
    has how;
    has who;
    has where;
    has file_ids = null;
    has date_created;
    has date_modified;
    has image_urls = null;
    has relatedMemories;
}


