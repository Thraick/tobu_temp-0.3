import {*} with "./conv_node.jac";
import {*} with "./conv_edge.jac";


graph dialogue_system {
    has anchor dialogue_root;

    spawn {

        bienc = file.load_json(global.train_classifer_path);
        dialogue_root = spawn node::dialog;

        faqs = spawn node::faqs(imprint = [{"list_imprint": bienc['faqs'], "name": "faqs"}], name="faqs");
        soc = spawn node::soc(imprint = [{"list_imprint":bienc['greetings'], "name": "greetings"}], name="greetings");
        eoc = spawn node::eoc(imprint = [{"list_imprint":bienc['goodbye'], "name": "goodbye"}], name="goodbye");

        document_memory = spawn node::document_memory(imprint = [{"list_imprint":bienc['document_memory'], "name": "document_memory"}], name="document_memory");
        
        events = spawn node::capture_memories(name="capture_memories");
        additional_memory = spawn node::additional_memory(name="additional_memory");
        unanswered_queue = spawn node::unanswered_queue(name="unanswered_queue");
        
        // save_memory = spawn node::save_memory(name="save_memory");
        confirm_save_memory = spawn node::summary_template(imprint = [{"list_imprint":bienc['confirm_save_memory'], "name": "confirm_save_memory"}], name="confirm_save_memory");

        dialogue_root +[intent_transition(intent="faqs")]+>faqs;
        dialogue_root +[intent_transition(intent="greetings")]+>soc;
        dialogue_root +[intent_transition(intent="goodbye")]+>eoc;
        dialogue_root +[intent_transition(intent="document_memory")]+>document_memory;
        dialogue_root +[redirect_transition]+> events;

        document_memory +[redirect_transition]+> events;

        events +[intent_transition(intent="faqs")]+>faqs;
        events +[intent_transition2(intent2="unanswered_queue")]+>unanswered_queue;
        events +[redirect_transition]+>additional_memory;

        // unanswered_queue +[redirect_transition]+>additional_memory;
        unanswered_queue +[intent_transition(intent="faqs")]+>faqs;
        unanswered_queue +[intent_transition2(intent2="additional_memory")]+>additional_memory;

        additional_memory +[intent_transition(intent="faqs")]+>faqs;
        additional_memory +[intent_transition(intent="confirm_save_memory")]+>confirm_save_memory;
        additional_memory +[redirect_transition]+>events;
        // additional_memory +[redirect_confirm_transition]+>save_memory;

        // save_memory +[intent_transition(intent="faqs")]+>faqs;
        // save_memory +[intent_transition(intent="confirm_save_memory")]+>confirm_save_memory;

    }
}


