# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/evaluator'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/reasoning/form_validator'

# Test comprehensive form validation using type constraints
# This demonstrates high business value through real-world form validation scenarios
class TestFormValidation < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    @form_validator = FormValidator.new(@evaluator)
    @error_log = []
    
    # Subscribe to validation events
    @form_validator.on_validation_error { |error| @error_log << error }
    @form_validator.on_validation_success { |result| @validation_results = result }
  end

  # === User Registration Form Validation ===

  def test_user_registration_form_complete_validation
    # Real-world user registration with multiple constraints
    form_definition = <<~PATLANG
      form user_registration {
        constrain username :: String where 
          length >= 3 and length <= 20 and 
          matches /^[a-zA-Z0-9_]+$/ and
          not_reserved_word;
          
        constrain email :: String where
          matches /^[\\w\\._%+-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$/ and
          unique_in_database;
          
        constrain password :: String where
          length >= 8 and
          contains_uppercase and
          contains_lowercase and
          contains_digit and
          contains_special_char and
          not_common_password;
          
        constrain age :: Number where
          age >= 13 and age <= 120;
          
        constrain terms_accepted :: Boolean where
          value == true;
      }
    PATLANG
    
    valid_data = {
      username: "john_doe123",
      email: "john.doe@example.com",
      password: "SecurePass123!",
      age: 25,
      terms_accepted: true
    }
    
    result = @form_validator.validate_form(:user_registration, form_definition, valid_data)
    
    assert result.valid?, "Valid user registration should pass validation"
    assert_empty result.errors, "Should have no validation errors"
    assert_equal valid_data, result.validated_data
  end

  def test_user_registration_form_multiple_validation_errors
    form_definition = <<~PATLANG
      form user_registration {
        constrain username :: String where length >= 3 and length <= 20;
        constrain email :: String where matches /^[\\w\\._%+-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$/;
        constrain password :: String where length >= 8 and contains_uppercase;
        constrain age :: Number where age >= 13 and age <= 120;
      }
    PATLANG
    
    invalid_data = {
      username: "ab",  # Too short
      email: "invalid-email",  # Invalid format
      password: "weak",  # Too short, no uppercase
      age: 10  # Too young
    }
    
    result = @form_validator.validate_form(:user_registration, form_definition, invalid_data)
    
    refute result.valid?, "Invalid data should fail validation"
    assert_equal 4, result.errors.length, "Should have 4 validation errors"
    
    # Check specific error messages
    username_error = result.errors.find { |e| e.field == :username }
    assert_includes username_error.message, "length >= 3"
    
    email_error = result.errors.find { |e| e.field == :email }
    assert_includes email_error.message, "matches"
    
    password_error = result.errors.find { |e| e.field == :password }
    assert_includes password_error.message, "length >= 8"
    
    age_error = result.errors.find { |e| e.field == :age }
    assert_includes age_error.message, "age >= 13"
  end

  # === E-commerce Product Form Validation ===

  def test_product_form_with_conditional_constraints
    form_definition = <<~PATLANG
      form product {
        constrain name :: String where length >= 1 and length <= 100;
        constrain price :: Number where price > 0 and price <= 99999.99;
        constrain category :: String where in_list(['electronics', 'books', 'clothing']);
        
        # Conditional constraints based on category
        constrain weight :: Number where 
          if category == 'electronics' then weight > 0 else weight >= 0;
          
        constrain isbn :: String where
          if category == 'books' then matches /^\\d{10}|\\d{13}$/ else optional;
          
        constrain size :: String where
          if category == 'clothing' then in_list(['XS', 'S', 'M', 'L', 'XL']) else optional;
      }
    PATLANG
    
    # Test electronics product
    electronics_data = {
      name: "Smartphone",
      price: 599.99,
      category: "electronics",
      weight: 0.18
    }
    
    result = @form_validator.validate_form(:product, form_definition, electronics_data)
    assert result.valid?, "Valid electronics product should pass validation"
    
    # Test book product
    book_data = {
      name: "Programming Guide",
      price: 49.99,
      category: "books",
      isbn: "9781234567890"
    }
    
    result = @form_validator.validate_form(:product, form_definition, book_data)
    assert result.valid?, "Valid book product should pass validation"
    
    # Test clothing product
    clothing_data = {
      name: "T-Shirt",
      price: 19.99,
      category: "clothing",
      size: "M"
    }
    
    result = @form_validator.validate_form(:product, form_definition, clothing_data)
    assert result.valid?, "Valid clothing product should pass validation"
  end

  # === Financial Transaction Form Validation ===

  def test_financial_transaction_form_with_security_constraints
    form_definition = <<~PATLANG
      form money_transfer {
        constrain from_account :: String where
          matches /^\\d{10,12}$/ and
          account_exists and
          sufficient_balance;
          
        constrain to_account :: String where
          matches /^\\d{10,12}$/ and
          account_exists and
          different_from(from_account);
          
        constrain amount :: Number where
          amount > 0 and
          amount <= daily_limit and
          amount <= account_balance;
          
        constrain currency :: String where
          in_list(['USD', 'EUR', 'GBP', 'JPY']) and
          supported_by_accounts(from_account, to_account);
          
        constrain purpose :: String where
          length >= 1 and
          length <= 200 and
          not_suspicious_keywords;
          
        constrain two_factor_code :: String where
          matches /^\\d{6}$/ and
          valid_totp_code;
      }
    PATLANG
    
    valid_transfer = {
      from_account: "1234567890",
      to_account: "0987654321",
      amount: 1000.00,
      currency: "USD",
      purpose: "Payment for services",
      two_factor_code: "123456"
    }
    
    result = @form_validator.validate_form(:money_transfer, form_definition, valid_transfer)
    
    # This should fail initially (RED phase) because FormValidator doesn't exist yet
    assert_raises(NameError) do
      @form_validator.validate_form(:money_transfer, form_definition, valid_transfer)
    end
  end

  # === Healthcare Form Validation ===

  def test_patient_intake_form_with_medical_constraints
    form_definition = <<~PATLANG
      form patient_intake {
        constrain patient_id :: String where
          matches /^P\\d{6}$/ and
          unique_patient_id;
          
        constrain date_of_birth :: Date where
          date <= today and
          age_from_date >= 0 and
          age_from_date <= 150;
          
        constrain blood_type :: String where
          in_list(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']);
          
        constrain allergies :: Array[String] where
          each_element(matches /^[A-Za-z\\s\\-]+$/) and
          length <= 20;
          
        constrain emergency_contact :: Object {
          name :: String where length >= 1 and length <= 100,
          phone :: String where matches /^\\+?[\\d\\s\\-\\(\\)]+$/,
          relationship :: String where length >= 1 and length <= 50
        };
        
        constrain insurance_policy :: String where
          matches /^[A-Z]{2}\\d{8}$/ and
          valid_insurance_policy;
      }
    PATLANG
    
    valid_patient_data = {
      patient_id: "P123456",
      date_of_birth: Date.new(1990, 5, 15),
      blood_type: "A+",
      allergies: ["Penicillin", "Shellfish"],
      emergency_contact: {
        name: "Jane Doe",
        phone: "+1-555-123-4567",
        relationship: "Spouse"
      },
      insurance_policy: "AB12345678"
    }
    
    # Test should initially fail (RED phase)
    assert_raises(NameError) do
      result = @form_validator.validate_form(:patient_intake, form_definition, valid_patient_data)
    end
  end

  # === Cross-Field Validation ===

  def test_cross_field_validation_constraints
    form_definition = <<~PATLANG
      form event_booking {
        constrain start_date :: Date where date >= today;
        constrain end_date :: Date where date >= start_date;
        constrain start_time :: Time where valid_time_format;
        constrain end_time :: Time where time > start_time;
        
        constrain adult_tickets :: Number where adult_tickets >= 0;
        constrain child_tickets :: Number where child_tickets >= 0;
        
        # Cross-field validation
        constrain total_tickets :: Number where
          total_tickets == (adult_tickets + child_tickets) and
          total_tickets > 0 and
          total_tickets <= max_capacity;
          
        constrain total_cost :: Number where
          total_cost == (adult_tickets * adult_price + child_tickets * child_price) and
          total_cost > 0;
      }
    PATLANG
    
    booking_data = {
      start_date: Date.today + 7,
      end_date: Date.today + 7,
      start_time: "14:00",
      end_time: "16:00",
      adult_tickets: 2,
      child_tickets: 1,
      total_tickets: 3,
      total_cost: 75.00  # Assuming $20 adult, $15 child
    }
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = @form_validator.validate_form(:event_booking, form_definition, booking_data)
    end
  end

  # === Performance and Scalability Tests ===

  def test_large_form_validation_performance
    # Test form with many fields and complex constraints
    form_definition = <<~PATLANG
      form large_survey {
        #{(1..100).map { |i| "constrain field_#{i} :: String where length >= 1 and length <= 1000;" }.join("\n        ")}
      }
    PATLANG
    
    large_data = (1..100).to_h { |i| ["field_#{i}".to_sym, "Valid data for field #{i}"] }
    
    start_time = Time.now
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = @form_validator.validate_form(:large_survey, form_definition, large_data)
      duration = Time.now - start_time
      assert_operator duration, :<, 1.0, "Large form validation should complete in <1 second"
    end
  end

  def test_nested_object_validation
    form_definition = <<~PATLANG
      form company_profile {
        constrain company :: Object {
          name :: String where length >= 1 and length <= 200,
          founded_year :: Number where founded_year >= 1800 and founded_year <= current_year,
          headquarters :: Object {
            street :: String where length >= 1 and length <= 100,
            city :: String where length >= 1 and length <= 50,
            country :: String where length == 2 and matches /^[A-Z]{2}$/,
            postal_code :: String where length >= 3 and length <= 10
          },
          employees :: Array[Object] {
            name :: String where length >= 1 and length <= 100,
            position :: String where length >= 1 and length <= 100,
            email :: String where matches /^[\\w\\._%+-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$/,
            salary :: Number where salary > 0 and salary <= 1000000
          }
        }
      }
    PATLANG
    
    company_data = {
      company: {
        name: "TechCorp Inc.",
        founded_year: 2015,
        headquarters: {
          street: "123 Tech Street",
          city: "San Francisco",
          country: "US",
          postal_code: "94105"
        },
        employees: [
          {
            name: "John Smith",
            position: "CEO",
            email: "john@techcorp.com",
            salary: 200000
          },
          {
            name: "Jane Johnson",
            position: "CTO",
            email: "jane@techcorp.com",
            salary: 180000
          }
        ]
      }
    }
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = @form_validator.validate_form(:company_profile, form_definition, company_data)
    end
  end

  # === Error Reporting and User Experience ===

  def test_detailed_error_reporting_with_field_paths
    form_definition = <<~PATLANG
      form user_profile {
        constrain profile :: Object {
          personal :: Object {
            first_name :: String where length >= 1 and length <= 50,
            last_name :: String where length >= 1 and length <= 50,
            age :: Number where age >= 13 and age <= 120
          },
          contact :: Object {
            email :: String where matches /^[\\w\\._%+-]+@[\\w\\.-]+\\.[A-Za-z]{2,}$/,
            phone :: String where matches /^\\+?[\\d\\s\\-\\(\\)]+$/
          }
        }
      }
    PATLANG
    
    invalid_data = {
      profile: {
        personal: {
          first_name: "",  # Invalid: empty
          last_name: "Doe",
          age: 12  # Invalid: too young
        },
        contact: {
          email: "invalid-email",  # Invalid: format
          phone: "555-1234"
        }
      }
    }
    
    # Should fail initially (RED phase)
    assert_raises(NameError) do
      result = @form_validator.validate_form(:user_profile, form_definition, invalid_data)
      
      refute result.valid?
      assert_equal 3, result.errors.length
      
      # Check field paths in error messages
      first_name_error = result.errors.find { |e| e.field_path == "profile.personal.first_name" }
      assert first_name_error, "Should have error for profile.personal.first_name"
      
      age_error = result.errors.find { |e| e.field_path == "profile.personal.age" }
      assert age_error, "Should have error for profile.personal.age"
      
      email_error = result.errors.find { |e| e.field_path == "profile.contact.email" }
      assert email_error, "Should have error for profile.contact.email"
    end
  end

  # === Integration with Existing Type Constraints ===

  def test_integration_with_unification_engine
    form_definition = <<~PATLANG
      form data_processing {
        constrain input_data :: UnifiableType where
          unifies_with(expected_pattern) and
          satisfies_business_rules;
          
        constrain transformation :: Function where
          type_signature(input_data -> output_data) and
          preserves_invariants;
      }
    PATLANG
    
    processing_data = {
      input_data: { type: "customer", id: 123, name: "John" },
      transformation: ->(data) { data.merge(processed: true) }
    }
    
    # Should fail initially (RED phase) - demonstrates integration need
    assert_raises(NameError) do
      result = @form_validator.validate_form(:data_processing, form_definition, processing_data)
    end
  end

  private

  def evaluate_patlang_code(code)
    parser = Parser.new(Lexer.new(code))
    ast = parser.parse
    @evaluator.evaluate(ast)
  rescue => e
    raise e.class, "Error evaluating: #{code.inspect}\nOriginal: #{e.message}", e.backtrace
  end
end

# === Supporting Classes that Should Exist After Implementation ===

# These classes represent the expected API after GREEN phase implementation

class FormValidator
  def initialize(evaluator)
    @evaluator = evaluator
    @event_handlers = {}
  end

  def on_validation_error(&block)
    @event_handlers[:validation_error] = block
  end

  def on_validation_success(&block)
    @event_handlers[:validation_success] = block
  end

  def validate_form(form_name, form_definition, data)
    # This method should be implemented during GREEN phase
    raise NotImplementedError, "FormValidator not yet implemented - this is RED phase"
  end
end

class ValidationResult
  attr_reader :errors, :validated_data

  def initialize(valid:, errors: [], validated_data: nil)
    @valid = valid
    @errors = errors
    @validated_data = validated_data
  end

  def valid?
    @valid
  end
end

class ValidationError
  attr_reader :field, :field_path, :message, :value

  def initialize(field:, field_path:, message:, value:)
    @field = field
    @field_path = field_path
    @message = message
    @value = value
  end
end