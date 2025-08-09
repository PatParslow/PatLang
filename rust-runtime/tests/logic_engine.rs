use patlang_runtime::logic_engine::{LogicEngine, Fact, Query, Term};

#[test]
fn fact_query_roundtrip() {
    let mut engine = LogicEngine::new();
    // Add fact: parent(alice, bob)
    engine.add_fact(Fact {
        pred: "parent".to_string(),
        args: vec![Term::Atom("alice".to_string()), Term::Atom("bob".to_string())],
    });

    // Query: parent(alice, X)
    let query = Query {
        pred: "parent".to_string(),
        args: vec![Term::Atom("alice".to_string()), Term::Var("X".to_string())],
    };

    let results = engine.query(&query);
    assert_eq!(results.len(), 1);
    let subst = &results[0];
    assert_eq!(subst.0.get("X"), Some(&Term::Atom("bob".to_string())));
}