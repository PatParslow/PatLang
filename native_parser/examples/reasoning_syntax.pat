# Reasoning Syntax Examples - Logic programming construct demonstrations
# These examples showcase PaTLang's reasoning capabilities

# Simple facts
fact parent(john, mary)
fact parent(mary, susan)
fact parent(bob, john)
fact age(john, 45)
fact age(mary, 25)
fact age(susan, 5)

# Basic rules
rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z)
rule sibling(X, Y) :- parent(Z, X), parent(Z, Y), X != Y
rule adult(Person) :- age(Person, Age), Age >= 18

# Complex rules with multiple conditions
rule can_vote(Person) :-
    age(Person, Age),
    Age >= 18,
    citizen(Person),
    registered(Person)

rule eligible_for_discount(Customer) :-
    age(Customer, Age),
    (Age >= 65 or student(Customer)),
    member(Customer)

# Goals with preconditions and postconditions
goal find_all_grandparents {
    precondition: parent_facts_loaded == true,
    postcondition: grandparents.length > 0,
    strategy: exhaustive_search
}

goal optimize_family_tree {
    precondition: all_relationships_defined == true,
    postcondition: tree.balanced == true and tree.complete == true,
    strategy: graph_optimization
}

# Reasoning mode control
reasoning mode on

# Queries and goal pursuit
pursue grandparent(bob, susan)
pursue find_all_grandparents

reasoning mode off

# Facts with complex structures
fact address(john, {street: "123 Main St", city: "Springfield", zip: "12345"})
fact contact(mary, {phone: "555-1234", email: "mary@example.com"})

# Rules with arithmetic
rule retirement_age(Person) :-
    age(Person, CurrentAge),
    RetirementAge is 65,
    CurrentAge >= RetirementAge

rule years_to_retirement(Person, Years) :-
    age(Person, CurrentAge),
    CurrentAge < 65,
    Years is 65 - CurrentAge

# Constrained reasoning
constrain valid_age :: Number where valid_age >= 0 and valid_age <= 150

rule valid_person(Person) :-
    age(Person, Age),
    constrain Age :: valid_age,
    Age > 0

# Mixed imperative and logic programming
x = 25
fact current_year(2024)
rule birth_year(Person, Year) :-
    age(Person, Age),
    current_year(CurrentYear),
    Year is CurrentYear - Age

# Nested reasoning within functions
make a function called find_relatives takes person
    reasoning mode on
    pursue parent(person, Child)
    pursue parent(Parent, person)
    relatives = [Child, Parent]
    reasoning mode off
    return relatives
end