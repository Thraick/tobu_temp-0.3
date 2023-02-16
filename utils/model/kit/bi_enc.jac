node bi_enc {
    can bi_enc.train, bi_enc.infer;

    can train {
        train_data = file.load_json(visitor.train_file);
        bi_enc.train(
            dataset=train_data,
            from_scratch=visitor.from_scratch,
            training_parameters={
                "num_train_epochs": visitor.num_train_epochs
            }
        );
        // if (visitor.model_name):
        //     bi_enc.save_model(model_path=visitor.model_name);
    }

    can infer {
        res = bi_enc.infer(
            contexts=[visitor.query],
            candidates=visitor.labels,
            context_type="text",
            candidate_type="text"
        )[0];
        std.out(res);
        visitor.prediction = res["predicted"];
    }
}

walker bi_enc_train {
    has train_file;
    has num_train_epochs = 100, from_scratch = true;
    root {
        take --> node::bi_enc else{
            spawn here ++> node::bi_enc;
            take --> node::bi_enc;
        }
    }
    bi_enc: here::train;
}

walker bi_enc_infer {
    has query, interactive = true;
    has labels, prediction;
    root {
        take --> node::bi_enc else{
            spawn here ++> node::bi_enc;
            take --> node::bi_enc;
        }
    }
    bi_enc {
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

walker bi_enc_save_model {
    has model_path;
    can bi_enc.save_model;
    bi_enc.save_model(model_path);
}

walker bi_enc_load_model {
    has model_path;
    can bi_enc.load_model;
    bi_enc.load_model(model_path);
}

walker bi_enc_delete {
    root {
        take --> node::bi_enc;
    }

    bi_enc {
        destroy here;
    }
}