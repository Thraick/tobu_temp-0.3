// node tfm_ner {
//     # train,infer
//     can tfm_ner.extract_entity, tfm_ner.train;

//     # extracting entities
//     can infer with predict_entity_from_tfm entry {
//         report tfm_ner.extract_entity(
//             text = visitor.query
//         );
//     }

//     ## train and validate
//     can train_and_val with train_and_val_tfm entry {

//         train_data = file.load_json(visitor.train_file);
//         // val_data = file.load_json(visitor.val_file);
//         // test_data = file.load_json(visitor.test_file);
//         // std.out("corpus : ",train_data.length," train + ",val_data.length," dev +",test_data.length," test sentences");
//         std.out("corpus : ",train_data.length);
//         tfm_ner.train(
//             mode = visitor.mode,
//             epochs = visitor.num_train_epochs.int,
//             train_data = train_data,
//             // dev_data = val_data,
//             // test_data = test_data
//             );
//         std.out("training and validation done ");
//         }
// }

// walker train_and_val_tfm {
//     has train_file;
//     has val_file;
//     has test_file;
//     has num_train_epochs;
//     has mode;

//     # Train all NER models on the train set
//     # and validate them on the val set
//     # report accuracy performance across all NER models
//     root {
//         take --> node::tfm_ner else{
//             spawn here ++> node::tfm_ner;
//             take --> node::tfm_ner;
//         }
//     }
//     // tfm_ner: here::train;
// }

// walker predict_entity_from_tfm{

//     has query, interactive = true;
//     has labels, prediction;
//     root {
//         take --> node::tfm_ner else{
//             spawn here ++> node::tfm_ner;
//             take --> node::tfm_ner;
//         }
//     }
//     tfm_ner {
//         if (interactive) {
//             while true {
//                 query = std.input("Enter input text (Ctrl-C to exit)> ");
//                 here::infer;
//                 std.out(prediction);
//             }
//         } else {
//             here::infer;
//             report prediction;
//         }
//     }
// }


###############################################
###############################################
###############################################
###############################################
###############################################
###############################################
###############################################
###############################################

node tfm_ner {
    can tfm_ner.train, tfm_ner.extract_entity;
    can train {
        train_data = file.load_json(visitor.train_file);
        std.out(train_data);
        tfm_ner.train(
            mode = visitor.mode,
            epochs = visitor.num_train_epochs,
            train_data = train_data,
            val_data = train_data
        );
    }
    can infer {
        res = tfm_ner.extract_entity(
            text = visitor.query
        );
        visitor.prediction = res;
    }
}

walker tfm_ner_train {
    has train_file;
    has num_train_epochs = 100;
    has mode = "incremental"; // default, incremental

    root {
        take --> node::tfm_ner else{
            spawn here ++> node::tfm_ner;
            take --> node::tfm_ner;
        }
    }
    tfm_ner: here::train;
}

walker tfm_ner_infer {
    has query, interactive = true;
    has labels, prediction;
    root {
        take --> node::tfm_ner else{
            spawn here ++> node::tfm_ner;
            take --> node::tfm_ner;
        }
    }
    tfm_ner {
        if (interactive) {
            while true {
                query = std.input("Enter input text (Ctrl-C to exit)> ");
                here::infer;
                std.out(prediction);
            }
        } else {
            here::infer;
            report prediction;
        }
    }
}

walker tfm_ner_save_model {
    has model_path;
    can tfm_ner.save_model;
    tfm_ner.save_model(model_path=model_path);
}

walker tfm_ner_load_model {
    has model_path;
    can tfm_ner.load_model;
    tfm_ner.load_model(model_path=model_path);
}

walker tfm_ner_delete {
    root {
        take --> node::tfm_ner;
    }

    tfm_ner {
        destroy here;
    }
}



