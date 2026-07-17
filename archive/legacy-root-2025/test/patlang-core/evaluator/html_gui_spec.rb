# frozen_string_literal: true

require_relative '../../../test/test_helper'
require_relative '../../../patlang-core/lexer/lexer'
require_relative '../../../patlang-core/parser/parser'
require_relative '../../../patlang-core/ast/ast_nodes'
require_relative '../../../patlang-core/evaluator/evaluator'

module Patlang
  module Evaluator
    RSpec.describe Evaluator do
      def eval_source(source, stdlib_modules = %w[core])
        lexer = Patlang::Lexer::Lexer.new(source)
        tokens = lexer.tokenize
        parser = Patlang::Parser::Parser.new(tokens)
        ast = parser.parse
        evaluator = Patlang::Evaluator::Evaluator.new(stdlib_modules)
        evaluator.eval(ast)
      end

      describe "standard library - html_gui module" do
        it "creates basic HTML document" do
          source = <<~PAT
            html_doc("My Page")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to include("<title>My Page</title>")
          expect(result).to include("<html")
        end
        
        it "creates HTML with custom head content" do
          source = <<~PAT
            html_doc_with_head("Test", "<meta name=\\\\\\\"viewport\\\\\\\" content=\\\\\\\"width=device-width\\\\\\\">")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to include("<title>Test</title>")
          expect(result).to include("viewport")
        end
        
        it "creates HTML elements" do
          source = <<~PAT
            html_element("div", { "class": "container", "id": "main" })
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to include("<div")
          expect(result).to include("class=\"container\"")
          expect(result).to include("id=\"main\"")
        end
        
        it "creates HTML elements with content" do
          source = <<~PAT
            html_element_with_content("p", { "class": "greeting" }, "Hello, World!")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<p class=\"greeting\">Hello, World!</p>")
        end
        
        it "provides semantic element shortcuts" do
          source = <<~PAT
            div({ "class": "wrapper" }, "Content here")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<div class=\"wrapper\">Content here</div>")
        end
        
        it "creates links" do
          source = <<~PAT
            a("https://example.com", "Click me")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<a href=\"https://example.com\">Click me</a>")
        end
        
        it "creates images" do
          source = <<~PAT
            img("image.png", "Alt text")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<img src=\"image.png\" alt=\"Alt text\">")
        end
        
        it "creates form elements" do
          source = <<~PAT
            input({ "type": "text", "name": "username", "placeholder": "Enter name" })
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to include("<input")
          expect(result).to include("type=\"text\"")
          expect(result).to include("name=\"username\"")
        end
        
        it "creates buttons" do
          source = <<~PAT
            button({ "type": "submit", "class": "btn" }, "Submit")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<button type=\"submit\" class=\"btn\">Submit</button>")
        end
        
        it "creates style tags" do
          source = <<~PAT
            style_tag(".container { max-width: 800px; margin: 0 auto; }")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<style>.container { max-width: 800px; margin: 0 auto; }</style>")
        end
        
        it "creates script tags" do
          source = <<~PAT
            script_tag("console.log('Hello');")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<script>console.log('Hello');</script>")
        end
        
        it "generates JavaScript event handlers" do
          source = <<~PAT
            on_click("btn1", "handleClick")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("document.getElementById('btn1').addEventListener('click', handleClick);")
        end
        
        it "generates DOM manipulation code" do
          source = <<~PAT
            dom_set_inner_html("app", "<h1>Hello</h1>")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("document.getElementById('app').innerHTML = '<h1>Hello</h1>';")
        end
        
        it "generates CSS manipulation code" do
          source = <<~PAT
            dom_set_style("box", "backgroundColor", "red")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("document.getElementById('box').style.backgroundColor = 'red';")
        end
        
        it "generates class manipulation code" do
          source = <<~PAT
            dom_add_class("menu", "active")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("document.getElementById('menu').classList.add('active');")
        end
        
        it "generates canvas drawing code" do
          source = <<~PAT
            canvas_draw_rect("ctx", 10, 20, 100, 50)
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("ctx.fillRect(10, 20, 100, 50);")
        end
        
        it "escapes HTML" do
          source = <<~PAT
            html_escape("<script>alert('xss')</script>")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;")
        end
        
        it "renders HTML to string" do
          source = <<~PAT
            html_to_string("<div>test</div>")
          PAT
          result = eval_source(source, %w[core html_gui])
          expect(result).to eq("<div>test</div>")
        end
      end
    end
  end
end