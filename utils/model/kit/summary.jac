walker summary {
    can t5_sum.classify_text;

    has category = "title";
    has text;
    has anchor results;

    if(category == "title") {
        
        results = t5_sum.classify_text(text=text, min_length=5, max_length=10);

    }
    else {
        results = t5_sum.classify_text(text=text, min_length=8, max_length=200);
        
    }
}