//! Tests for GoalSystem core module

use patlang_runtime::goal_system::{GoalSystem, Goal, GoalStatus, GoalEventListener, GoalId};
use std::sync::{Arc, Mutex};

struct TestListener {
    declared: Mutex<bool>,
    pursued: Mutex<bool>,
}
impl GoalEventListener for TestListener {
    fn on_goal_declared(&self, _goal: &Goal) {
        *self.declared.lock().unwrap() = true;
    }
    fn on_goal_pursued(&self, _goal: &Goal) {
        *self.pursued.lock().unwrap() = true;
    }
}


#[test]
fn test_goal_declaration_and_pursuit() {
    let system = GoalSystem::new();
    let listener = Arc::new(TestListener {
        declared: Mutex::new(false),
        pursued: Mutex::new(false),
    });
    system.register_listener(listener.clone());

    let goal_id: GoalId = "goal1".to_string();
    let description = "Test goal".to_string();

    system.declare_goal(goal_id.clone(), description.clone());

    assert_eq!(*listener.declared.lock().unwrap(), true);

    system.pursue_goal(&goal_id);

    assert_eq!(*listener.pursued.lock().unwrap(), true);
    // The public API sets status to Completed after pursuit, so check for Completed.
    assert_eq!(system.get_goal_status(&goal_id), Some(GoalStatus::Completed));
}

#[test]
fn test_goal_status_transitions() {
    let system = GoalSystem::new();
    let goal_id: GoalId = "goal2".to_string();
    let description = "Another goal".to_string();

    system.declare_goal(goal_id.clone(), description);

    // Move to Completed (pursue_goal sets to Completed)
    system.pursue_goal(&goal_id);
    assert_eq!(
        system.get_goal_status(&goal_id),
        Some(GoalStatus::Completed)
    );
}