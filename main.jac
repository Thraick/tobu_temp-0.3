import {*} with "./conv_walkers.jac";
import {*} with "./conv_graph.jac";
import {*} with "./globals.jac";

import {*} with './utils/model/kit/bi_enc.jac';
import {*} with './utils/model/kit/tfm_ner.jac';
import {*} with "./utils/model/kit/summary.jac";


walker init {
    root{
        global.main_root = here.info["jid"];

        take -[dialog]-> node::dialog else{
            spawn here +[user]+> node::user;
            spawn here +[dialog]+> graph::dialogue_system;
            spawn here walker::ingest_faq;
            take -[dialog]-> node::dialog;
        }
    }
    dialog{
        global.dialogue_root = here.info['jid'];
    }
}