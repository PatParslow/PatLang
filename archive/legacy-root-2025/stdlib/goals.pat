# PatLang Standard Library - Goals Module
# Goal-oriented programming functions
# Implemented in PatLang with foreign primitives for goal system access

import "core.pat"
import "logic.pat"

# Goal system access (foreign)
make a function called goal_system_get {
  takes:
}

make a function called goal_system {
  takes:
}

# Declare a goal
make a function called declare_goal {
  takes: name, defn
}

# Pursue/activate goal (simple)
make a function called pursue {
  takes: goal_name
}

make a function called pursue_with {
  takes: goal_name, ctx
}

# Pursue multiple goals concurrently
make a function called pursue_all {
  takes: goal_names, ctx
}

# Create execution plan
make a function called execution_plan {
  takes: goal_name
}

# Start monitoring
make a function called monitor_goal {
  takes: goal_name
}

# Get goal by name
make a function called get_goal {
  takes: name
}

# List all goals
make a function called all_goals {
  takes:
}

# Resource scheduler
make a function called resource_scheduler {
  takes:
}

# Goal definition structure
make a function called goal_defn {
  takes: name, desc, reqs, ach, body
}

# Declare a structured goal
make a function called declare_structured_goal {
  takes: gdef
}

# Pursue goal and wait for completion
make a function called pursue_and_wait {
  takes: goal_name, ctx
}

# Pursue multiple goals sequentially
make a function called pursue_sequentially {
  takes: goal_names, ctx
}