from transformers import T5ForConditionalGeneration, T5Tokenizer

model = T5ForConditionalGeneration.from_pretrained('t5-small')
# tokenizer = T5Tokenizer.from_pretrained('t5-small')
tokenizer = T5Tokenizer.from_pretrained('t5-small', model_max_length=1024)


def generate_question(word1, word2):
    input_text = f"{word1} and {word2}"
    input_ids = tokenizer.encode(input_text, return_tensors='pt')
    # outputs = model.generate(input_ids=input_ids,
    #                          max_length=50,
    #                          do_sample=True)
    outputs = model.generate(input_ids=input_ids, do_sample=True, max_length=1024)

    question = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return question


ee = generate_question("old", "anna")
print(ee)