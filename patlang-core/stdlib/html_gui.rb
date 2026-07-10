# frozen_string_literal: true

# PatLang Standard Library - HTML/JS Rendering Module
# Provides platform-independent GUI layer through HTML/JavaScript rendering

module Patlang
  module Stdlib
    module HtmlGui
      FUNCTIONS = {}

      def self.register(name, arity, &block)
        FUNCTIONS[name] = { arity: arity, impl: block }
      end

      def self.get(name)
        FUNCTIONS[name]
      end

      def self.all
        FUNCTIONS.keys
      end

      def self.init!
        # HTML document creation
        register("html_doc", 1) do |args, env|
          title = args[0].to_s
          <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{title}</title>
          </head>
          <body></body>
          </html>
          HTML
        end

        register("html_doc_with_head", 2) do |args, env|
          title = args[0].to_s
          head_content = args[1].to_s
          <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{title}</title>
            #{head_content}
          </head>
          <body></body>
          </html>
          HTML
        end

        # HTML element creation
        register("html_element", 2) do |args, env|
          tag = args[0].to_s
          attrs = if args[1].is_a?(Hash) then args[1] else {} end

          attr_str = attrs.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')
          attr_str = " #{attr_str}" unless attr_str.empty?

          "<#{tag}#{attr_str}></#{tag}>"
        end

        register("html_element_with_content", 3) do |args, env|
          tag = args[0].to_s
          attrs = if args[1].is_a?(Hash) then args[1] else {} end
          content = args[2].to_s

          attr_str = attrs.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')
          attr_str = " #{attr_str}" unless attr_str.empty?

          "<#{tag}#{attr_str}>#{content}</#{tag}>"
        end

        # Common semantic elements
        register("div", -1) { |args, env| html_element_with_content("div", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("span", -1) { |args, env| html_element_with_content("span", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("p", -1) { |args, env| html_element_with_content("p", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("h1", -1) { |args, env| html_element_with_content("h1", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("h2", -1) { |args, env| html_element_with_content("h2", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("h3", -1) { |args, env| html_element_with_content("h3", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("a", -1) { |args, env| html_element_with_content("a", { "href" => args[0] }, args[1] || "") }
        register("img", -1) { |args, env| "<img src=\"#{args[0]}\"#{args[1] ? " alt=\"#{args[1]}\"" : ""}>" }
        register("input", -1) { |args, env| "<input#{args[0] ? " " + args[0].map { |k,v| "#{k}=\"#{v}\"" }.join(' ') : ""}>" }
        register("button", -1) { |args, env| html_element_with_content("button", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("ul", -1) { |args, env| html_element_with_content("ul", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("ol", -1) { |args, env| html_element_with_content("ol", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("li", -1) { |args, env| html_element_with_content("li", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("table", -1) { |args, env| html_element_with_content("table", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("tr", -1) { |args, env| html_element_with_content("tr", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("td", -1) { |args, env| html_element_with_content("td", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("th", -1) { |args, env| html_element_with_content("th", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("form", -1) { |args, env| html_element_with_content("form", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("label", -1) { |args, env| html_element_with_content("label", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("select", -1) { |args, env| html_element_with_content("select", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("option", -1) { |args, env| html_element_with_content("option", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }
        register("textarea", -1) { |args, env| html_element_with_content("textarea", (args[0].is_a?(Hash) ? args[0] : {}), args[1] || "") }

        # CSS stylesheet inclusion
        register("style_tag", 1) do |args, env|
          "<style>#{args[0]}</style>"
        end

        register("link_stylesheet", 1) do |args, env|
          "<link rel=\"stylesheet\" href=\"#{args[0]}\">"
        end

        # JavaScript inclusion
        register("script_tag", 1) do |args, env|
          "<script>#{args[0]}</script>"
        end

        register("link_script", 1) do |args, env|
          "<script src=\"#{args[0]}\"></script>"
        end

        # JavaScript execution context
        register("js_eval", 1) do |args, env|
          # Placeholder for JS evaluation - would integrate with JavaScript engine
          "# JS: #{args[0]}"
        end

        register("js_function", 2) do |args, env|
          name = args[0].to_s
          body = args[1].to_s
          "function #{name}() { #{body} }"
        end

        register("js_event_handler", 3) do |args, env|
          element_id = args[0].to_s
          event = args[1].to_s
          handler = args[2].to_s
          "document.getElementById('#{element_id}').addEventListener('#{event}', #{handler});"
        end

        # DOM manipulation helpers
        register("dom_get_by_id", 1) do |args, env|
          "document.getElementById('#{args[0]}')"
        end

        register("dom_query_selector", 1) do |args, env|
          "document.querySelector('#{args[0]}')"
        end

        register("dom_query_selector_all", 1) do |args, env|
          "document.querySelectorAll('#{args[0]}')"
        end

        register("dom_set_attribute", 3) do |args, env|
          "document.getElementById('#{args[0]}').setAttribute('#{args[1]}', '#{args[2]}');"
        end

        register("dom_get_attribute", 2) do |args, env|
          "document.getElementById('#{args[0]}').getAttribute('#{args[1]}')"
        end

        register("dom_set_inner_html", 2) do |args, env|
          "document.getElementById('#{args[0]}').innerHTML = '#{args[1]}';"
        end

        register("dom_append_child", 2) do |args, env|
          "document.getElementById('#{args[0]}').appendChild(#{args[1]});"
        end

        register("dom_remove_child", 2) do |args, env|
          "document.getElementById('#{args[0]}').removeChild(#{args[1]});"
        end

        register("dom_create_element", 1) do |args, env|
          "document.createElement('#{args[0]}')"
        end

        register("dom_create_text_node", 1) do |args, env|
          "document.createTextNode('#{args[0]}')"
        end

        # CSS manipulation
        register("dom_set_style", 3) do |args, env|
          "document.getElementById('#{args[0]}').style.#{args[1]} = '#{args[2]}';"
        end

        register("dom_get_style", 2) do |args, env|
          "document.getElementById('#{args[0]}').style.#{args[1]}"
        end

        register("dom_add_class", 2) do |args, env|
          "document.getElementById('#{args[0]}').classList.add('#{args[1]}');"
        end

        register("dom_remove_class", 2) do |args, env|
          "document.getElementById('#{args[0]}').classList.remove('#{args[1]}');"
        end

        register("dom_toggle_class", 2) do |args, env|
          "document.getElementById('#{args[0]}').classList.toggle('#{args[1]}');"
        end

        # Event system
        register("on_click", 2) { |args, env| js_event_handler(args[0], "click", args[1]) }
        register("on_change", 2) { |args, env| js_event_handler(args[0], "change", args[1]) }
        register("on_submit", 2) { |args, env| js_event_handler(args[0], "submit", args[1]) }
        register("on_input", 2) { |args, env| js_event_handler(args[0], "input", args[1]) }
        register("on_keydown", 2) { |args, env| js_event_handler(args[0], "keydown", args[1]) }
        register("on_keyup", 2) { |args, env| js_event_handler(args[0], "keyup", args[1]) }
        register("on_mouseover", 2) { |args, env| js_event_handler(args[0], "mouseover", args[1]) }
        register("on_mouseout", 2) { |args, env| js_event_handler(args[0], "mouseout", args[1]) }

        # Canvas API
        register("canvas_create", 2) do |args, env|
          "var canvas = document.createElement('canvas'); canvas.width = #{args[0]}; canvas.height = #{args[1]}; canvas;"
        end

        register("canvas_get_context", 1) do |args, env|
          variable = args[0]
          "var ctx = #{variable}.getContext('2d');"
        end

        register("canvas_draw_rect", 5) do |args, env|
          ctx = args[0]; x = args[1]; y = args[2]; w = args[3]; h = args[4]
          "#{ctx}.fillRect(#{x}, #{y}, #{w}, #{h});"
        end

        register("canvas_draw_circle", 4) do |args, env|
          ctx = args[0]; x = args[1]; y = args[2]; r = args[3]
          "#{ctx}.beginPath(); #{ctx}.arc(#{x}, #{y}, #{r}, 0, 2 * Math.PI); #{ctx}.fill();"
        end

        register("canvas_set_fill_style", 2) do |args, env|
          ctx = args[0]; color = args[1]
          "#{ctx}.fillStyle = '#{color}';"
        end

        register("canvas_set_stroke_style", 2) do |args, env|
          ctx = args[0]; color = args[1]
          "#{ctx}.strokeStyle = '#{color}';"
        end

        register("canvas_draw_line", 5) do |args, env|
          ctx = args[0]; x1 = args[1]; y1 = args[2]; x2 = args[3]; y2 = args[4]
          "#{ctx}.beginPath(); #{ctx}.moveTo(#{x1}, #{y1}); #{ctx}.lineTo(#{x2}, #{y2}); #{ctx}.stroke();"
        end

        render_to_file = lambda do |args, env|
          filename = args[0]
          content = args[1]
          File.write(filename, content)
          "Wrote #{content.length} bytes to #{filename}"
        end
        register("render_to_file", 2, &render_to_file)

        # HTML rendering and browser launch
        register("html_to_string", 1) do |args, env|
          args[0].to_s
        end

        register("html_escape", 1) do |args, env|
          args[0].to_s
            .gsub("&", "&amp;")
            .gsub("<", "&lt;")
            .gsub(">", "&gt;")
            .gsub('"', "&quot;")
            .gsub("'", "&#39;")
        end

        # Component system (simple virtual DOM-like)
        register("component", 2) do |args, env|
          name = args[0].to_s
          render_fn = args[1]
          "/* Component: #{name} */\n#{render_fn.to_s}"
        end

        register("render_component", 2) do |args, env|
          component = args[0]
          props = args[1] || {}
          "/* Rendering component with props: #{props} */"
        end

      end

      # Helper methods
      def self.html_element(tag, attrs = {}, content = "")
        attr_str = attrs.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')
        attr_str = " #{attr_str}" unless attr_str.empty?
        "<#{tag}#{attr_str}>#{content}</#{tag}>"
      end

      def self.html_element_with_content(tag, attrs, content)
        html_element(tag, attrs, content)
      end

      def self.js_event_handler(element_id, event, handler)
        "document.getElementById('#{element_id}').addEventListener('#{event}', #{handler});"
      end

      init!
    end
  end
end