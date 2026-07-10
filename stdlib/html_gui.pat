# PatLang Standard Library - HTML/GUI Module
# Provides platform-independent GUI layer through HTML/JavaScript rendering

import "core.pat"
import "collections.pat"

# HTML document creation
make a function called html_doc {
  takes: title
}

make a function called html_doc_with_head {
  takes: title, head_content
}

# HTML element creation
make a function called html_element {
  takes: tag, attrs, content
}

make a function called html_element_with_content {
  takes: tag, attrs, content
}

# Convenience functions for common semantic elements
make a function called div {
  takes: attrs_or_content, content
}

make a function called span {
  takes: attrs_or_content, content
}

make a function called p {
  takes: attrs_or_content, content
}

make a function called h1 {
  takes: attrs_or_content, content
}

make a function called h2 {
  takes: attrs_or_content, content
}

make a function called h3 {
  takes: attrs_or_content, content
}

make a function called a {
  takes: href_or_attrs, content
}

make a function called img {
  takes: src, alt
}

make a function called input {
  takes: attrs
}

make a function called button {
  takes: attrs_or_content, content
}

make a function called ul {
  takes: attrs_or_content, content
}

make a function called ol {
  takes: attrs_or_content, content
}

make a function called li {
  takes: attrs_or_content, content
}

make a function called table {
  takes: attrs_or_content, content
}

make a function called tr {
  takes: attrs_or_content, content
}

make a function called td {
  takes: attrs_or_content, content
}

make a function called th {
  takes: attrs_or_content, content
}

make a function called form {
  takes: attrs_or_content, content
}

make a function called label {
  takes: attrs_or_content, content
}

make a function called select_elem {
  takes: attrs_or_content, content
}

make a function called option {
  takes: attrs_or_content, content
}

make a function called textarea {
  takes: attrs_or_content, content
}

# CSS stylesheet inclusion
make a function called style_tag {
  takes: css
}

make a function called link_stylesheet {
  takes: href
}

# JavaScript inclusion
make a function called script_tag {
  takes: js
}

make a function called link_script {
  takes: src
}

# JavaScript execution context (foreign)
make a function called js_eval {
  takes: js
}

make a function called js_function {
  takes: name, body
}

make a function called js_event_handler {
  takes: elem_id, event, handler
}

# DOM manipulation helpers (foreign)
make a function called dom_get_by_id {
  takes: id
}

make a function called dom_query_selector {
  takes: selector
}

make a function called dom_query_selector_all {
  takes: selector
}

make a function called dom_set_attribute {
  takes: elem_id, attr, val
}

make a function called dom_get_attribute {
  takes: elem_id, attr
}

make a function called dom_set_inner_html {
  takes: elem_id, html
}

make a function called dom_append_child {
  takes: parent_id, child
}

make a function called dom_remove_child {
  takes: parent_id, child
}

make a function called dom_create_element {
  takes: tag
}

make a function called dom_create_text_node {
  takes: txt
}

# CSS manipulation (foreign)
make a function called dom_set_style {
  takes: elem_id, prop, val
}

make a function called dom_get_style {
  takes: elem_id, prop
}

make a function called dom_add_class {
  takes: elem_id, cls
}

make a function called dom_remove_class {
  takes: elem_id, cls
}

make a function called dom_toggle_class {
  takes: elem_id, cls
}

# Event system (foreign)
make a function called on_click {
  takes: elem_id, handler
}

make a function called on_change {
  takes: elem_id, handler
}

make a function called on_submit {
  takes: elem_id, handler
}

make a function called on_input {
  takes: elem_id, handler
}

make a function called on_keydown {
  takes: elem_id, handler
}

make a function called on_keyup {
  takes: elem_id, handler
}

make a function called on_mouseover {
  takes: elem_id, handler
}

make a function called on_mouseout {
  takes: elem_id, handler
}

# Canvas API (foreign)
make a function called canvas_create {
  takes: w, h
}

make a function called canvas_get_context {
  takes: canvas
}

make a function called canvas_draw_rect {
  takes: ctx, x, y, w, h
}

make a function called canvas_draw_circle {
  takes: ctx, x, y, r
}

make a function called canvas_set_fill_style {
  takes: ctx, color
}

make a function called canvas_set_stroke_style {
  takes: ctx, color
}

make a function called canvas_draw_line {
  takes: ctx, x1, y1, x2, y2
}

# HTML rendering and file output
make a function called render_to_file {
  takes: filename, content
}

make a function called html_to_string {
  takes: html
}

make a function called html_escape {
  takes: txt
}

make a function called string_escape_html {
  takes: txt
}

# Component system (simple virtual DOM-like)
make a function called component {
  takes: name, render_fn
}

make a function called render_component {
  takes: comp, props
}

# Higher-level UI helpers
make a function called card {
  takes: title, content, footer
}

make a function called btn {
  takes: txt, variant, onclick
}

make a function called form_field {
  takes: label_text, name, type, val, req
}

make a function called modal {
  takes: id, title, content, footer
}

make a function called navbar {
  takes: brand, links
}

make a function called data_table {
  takes: headers, rows
}