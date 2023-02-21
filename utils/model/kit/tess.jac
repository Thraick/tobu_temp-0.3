walker test_get_embeddings { 
    has text_list;
    has text_str;
    has max_length = 30;
    has min_length = 10;
    has num_return_sequences = 3;

    can gpt2.get_embeddings; 
    can gpt2.generate; 

    if (text_list){
        report gpt2.generate(
            text= text_list,
            max_length= max_length,
            min_length= min_length,
            num_return_sequences = num_return_sequences
        ); 
    }
    elif(text_str){
        std.out("text_str");
        std.out(text_str);
        std.out(text_str.list.length);
        report gpt2.generate(
            text= text_str,
            max_length= max_length,
            min_length= min_length,
            num_return_sequences = num_return_sequences
        ); 
    }
}

walker test_train {
    can gpt2.train;
    can file.load_str;
    text= file.load_str("jac_nlp/jac_nlp/gpt2/tests/german_recipes.txt");
    gpt2.train(text, 1);
}

// jac run file_path -walk walker_nane -ctx "{"key": "value"}
// jac run "utils/model/kit/tess.jac" -walk test_get_embeddings

// walker run test_get_embeddings -ctx "{\"text_str\": \"The weather was sunny\", \"max_length\": 10,\"min_length\": 5,\"num_return_sequences\": 2}"
// walker run test_get_embeddings -ctx "{\"text_str\": \"The weather was sunny\", \"max_length\": 20}"

walker train_module{
    can sbert_sim.train;
    has train_data= [
                    ["A person is on a baseball team.","A person is playing basketball on a team.",0.99],
                    ["Our current vehicles will be in museums when everyone has their own aircraft.","The car needs to some work",0.99],
                    ["A woman supervisor is instructing the male workers.","A woman is working as a nurse.",0.99]
                ];
    report sbert_sim.train(train_data,{'num_epochs':2});
    }

walker get_sim_score{
    can sbert_sim.get_text_sim;
    report sbert_sim.get_text_sim("A girl dancing on a sandy beach.","A girl is on a sandy beach.",1);
    }
    
// walker run train_module
// walker run get_sim_score



walker t5_summary{
    has text;
    has min_length;
    has max_length;
    # import ability
    can t5_sum.classify_text;

    std.out("text.list.length");
    std.out(text.list.length);

    # summarizer
    report t5_sum.classify_text(
        text = text,
        min_length = min_length,
        max_length = max_length
    );
}

// walker run t5_summary -ctx "{\"text\": \"Yes i was there alone.\", \"max_length\": 114,\"min_length\": 10}"



walker check{
    can use.text_classify;

    with exit{


        post_summary = [
                "a review of 130 oil contracts was conducted by Kaieteur News. the findings were alarming, revealing the extent to which the deal is fraught with unfair provisions. today, we start with the provision that speaks to the u.s.",
                "ExxonMobil has put on hold the FPSO vessel, called Prosperity. work had recently started on the construction, despite the fact that the government has not greenlit the project. the vessel was discovered in a recent press statement.",
                "the city of Charleston, south Carolina (SC), has slapped exxonMobil and 23 other fossil fuel giants for their deception on climate change, the contributions of their operations to this global phenomenon, and the inherent costs to now deal with the consequences of increasing floods and rising temperatures.",
                "the murdered teens were laid to rest in a memorable, grand and primarily peaceful manner. the bodies of the teenagers were found in the clumps of bushes next to the coconut Estate in south america in august - july 19 and august 19 saturday night in an area of about 2,000 square feet surrounded by weeds and shrubs. Isaiah Henry, 16, and Joel, 19, were buried at the estate in dec",
                "Isaiah Henry, 16, and his cousin, Joel, 18, were slain in the brutal murder of the boys while. a lawyer for some of those arrested accuses the police of going to the u.s."
            ];
        classes = [
                "Domestic violence is not physical violence alone. Domestic violence is any behavior the purpose of which is to gain power and control over a spouse, partner, girl/boyfriend or intimate family member. Abuse is a learned behavior; it is not caused by anger, mental problems, drugs or alcohol, or other common excuses.",
                "Your partner apologizes and says the hurtful behavior won't happen again — but you fear it will. At times you wonder whether you're imagining the abuse, yet the emotional or physical pain you feel is real. If this sounds familiar, you might be experiencing domestic violence.",
                "Abusive relationships always involve an imbalance of power and control. An abuser uses intimidating, hurtful words and behaviors to control a partner.",
                "the criminal act of deliberately setting fire to property."
            ];

        for p in post_summary{
            resp = use.text_classify(
                text = p,
                classes = classes
            );
            result.list::append({"text":p, "class_pred":resp["match"]});
            // report result;
            std.out(result);
        }

        // report post_nodes;
        // report classes;
        // report result;
    }
}
// walker run check