use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn test_build_configuration_load_and_targets() {
    let src = r#"
config = BuildConfiguration.load_from_file("nonexistent.yaml")
targets = config.targets()
print(targets)
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    // Should produce a list id
    assert!(res.message.starts_with("__list_"));
    // And object snapshot should include BuildConfiguration_* with targets property
    assert!(res.objects.iter().any(|(name, props)| name.starts_with("BuildConfiguration_") && props.iter().any(|(k, _)| k == "targets")));
}

#[test]
fn test_build_dependency_graph_and_execute_build() {
    let src = r#"
orchestrator = BuildOrchestrator.new()
list = list_new()
list.add("web_app")
list.add("api_server")

graph = build_dependency_graph(list)
orchestrator.dependency_graph = graph

results = orchestrator.execute_build(list, BuildOptions.release())
print(results)
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    // results is an object id BuildResults_*
    assert!(res.message.starts_with("BuildResults_"));
    // Check BuildResults object snapshot contains expected properties
    let (_, props) = res
        .objects
        .iter()
        .find(|(n, _)| n == &res.message)
        .expect("build results present");
    assert!(props.iter().any(|(k, _)| k == "mode"));
    assert!(props.iter().any(|(k, _)| k == "successful"));
    assert!(props.iter().any(|(k, _)| k == "targets"));
}

#[test]
fn test_parallel_collect_clones_list() {
    let src = r#"
xs = list_new()
xs.add("1")
ys = xs.parallel_collect()
print(ys)
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    assert!(res.message.starts_with("__list_"));
}

#[test]
fn test_cache_configuration_sets_value() {
    let src = r#"
cfg = BuildConfiguration.load_from_file("nonexistent.yaml")
cc = cfg.cache_configuration()
print(cc)
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    assert!(res.message.ends_with("nonexistent.yaml"));
}
