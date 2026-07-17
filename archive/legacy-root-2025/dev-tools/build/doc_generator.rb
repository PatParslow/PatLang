#!/usr/bin/env ruby

# Patlang Documentation Generator
# Converts markdown files to linked HTML pages

require 'fileutils'

class PatLangDocGenerator
  def initialize(docs_dir = 'docs', output_dir = 'docs_html')
    @docs_dir = docs_dir
    @output_dir = output_dir
    @files = []
  end

  def generate
    puts "Generating Patlang documentation website..."
    
    # Create output directory
    FileUtils.mkdir_p(@output_dir)
    
    # Scan for markdown files
    scan_markdown_files
    
    # Generate HTML files
    @files.each { |file| convert_file(file) }
    
    # Generate index page
    generate_index
    
    # Copy CSS
    generate_css
    
    puts "Documentation generated in #{@output_dir}/"
    puts "Open #{@output_dir}/index.html in your browser"
  end

  private

  def scan_markdown_files
    Dir.glob("#{@docs_dir}/**/*.md").each do |file|
      relative_path = file.gsub("#{@docs_dir}/", '')
      @files << {
        source: file,
        relative: relative_path,
        html: relative_path.gsub('.md', '.html'),
        title: extract_title(file)
      }
    end
  end

  def extract_title(file)
    first_line = File.readlines(file).first
    if first_line&.start_with?('#')
      first_line.gsub(/^#+\s*/, '').strip
    else
      File.basename(file, '.md').gsub(/[-_]/, ' ').split.map(&:capitalize).join(' ')
    end
  end

  def convert_file(file_info)
    puts "Converting #{file_info[:relative]}..."
    
    content = File.read(file_info[:source])
    html_content = markdown_to_html(content)
    
    # Create directory structure
    output_path = File.join(@output_dir, file_info[:html])
    FileUtils.mkdir_p(File.dirname(output_path))
    
    # Generate full HTML page
    html_page = generate_html_page(file_info[:title], html_content)
    File.write(output_path, html_page)
  end

  def markdown_to_html(content)
    # Simple markdown to HTML conversion
    html = content.dup
    
    # Headers
    html.gsub!(/^### (.+)$/, '<h3>\1</h3>')
    html.gsub!(/^## (.+)$/, '<h2>\1</h2>')
    html.gsub!(/^# (.+)$/, '<h1>\1</h1>')
    
    # Code blocks with Patlang syntax highlighting
    html.gsub!(/```patlang\n(.*?)\n```/m) do |match|
      code = $1
      highlighted = highlight_patlang_code(code)
      "<pre><code class=\"language-patlang\">#{highlighted}</code></pre>"
    end
    
    # Generic code blocks
    html.gsub!(/```(\w+)?\n(.*?)\n```/m) do |match|
      lang = $1 || 'text'
      code = $2
      "<pre><code class=\"language-#{lang}\">#{escape_html(code)}</code></pre>"
    end
    
    # Inline code
    html.gsub!(/`([^`]+)`/, '<code>\1</code>')
    
    # Links
    html.gsub!(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
    
    # Bold and italic
    html.gsub!(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
    html.gsub!(/\*([^*]+)\*/, '<em>\1</em>')
    
    # Lists
    html.gsub!(/^- (.+)$/, '<li>\1</li>')
    html.gsub!(/<li>.*?<\/li>/m) { |match| "<ul>#{match}</ul>" }
    
    # Paragraphs
    html.split("\n\n").map do |para|
      para = para.strip
      next para if para.start_with?('<h', '<p', '<u', '<o', '<c', '<pre')
      para.empty? ? '' : "<p>#{para}</p>"
    end.join("\n\n")
  end

  def highlight_patlang_code(code)
    highlighted = escape_html(code)
    
    # Keywords
    highlighted.gsub!(/\b(make|a|called|takes|returns|has|is|when|emit|with|if|then|else|elsif|end|while|for|in|do|case|and|or|not|true|false|class|function|goal|query|try|catch|activate)\b/, '<span class="keyword">\1</span>')
    
    # Types
    highlighted.gsub!(/\b(number|text|time|email|list|template)\b/, '<span class="type">\1</span>')
    
    # Strings
    highlighted.gsub!(/"([^"]*)"/, '<span class="string">"\1"</span>')
    
    # Numbers
    highlighted.gsub!(/\b\d+\.?\d*\b/, '<span class="number">\0</span>')
    
    # Comments
    highlighted.gsub!(/#(.*)$/, '<span class="comment">#\1</span>')
    
    # Operators
    highlighted.gsub!(/([+\-*\/=<>!]+)/, '<span class="operator">\1</span>')
    
    highlighted
  end

  def escape_html(text)
    text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def generate_html_page(title, content)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{title} - Patlang Documentation</title>
          <link rel="stylesheet" href="/patlang/docs_html/patlang-docs.css">
      </head>
      <body>
          <nav class="sidebar">
              <h2>Patlang Documentation</h2>
              #{generate_navigation}
          </nav>
          <main class="content">
              #{content}
          </main>
      </body>
      </html>
    HTML
  end

  def generate_navigation
    nav_html = ""
    
    # Group files by directory
    grouped = @files.group_by { |f| File.dirname(f[:relative]) }
    
    grouped.each do |dir, files|
      if dir == '.'
        nav_html += "<div class=\"nav-section\">\n"
      else
        nav_html += "<div class=\"..\">\n<h3>#{dir.capitalize}</h3>\n"
      end
      
      files.each do |file|
        nav_html += "<a href=\"#{file[:html]}\">#{file[:title]}</a>\n"
      end
      
      nav_html += "</div>\n"
    end
    
    nav_html
  end

  def generate_index
    index_content = <<~HTML
      <h1>Patlang Documentation</h1>
      <p>Welcome to the Patlang programming language documentation.</p>
      
      <h2>Quick Links</h2>
      <ul>
          <li><a href="language/Patlang.html">Language Overview</a></li>
          <li><a href="development/next-increment-plan.html">Development Roadmap</a></li>
          <li><a href="development/self-hosting-gap-analysis.html">Self-Hosting Analysis</a></li>
          <li><a href="examples/example_functional.html">Examples</a></li>
      </ul>
      
      <h2>All Documentation</h2>
      #{generate_file_list}
    HTML
    
    html_page = generate_html_page("Patlang Documentation", index_content)
    File.write(File.join(@output_dir, 'index.html'), html_page)
  end

  def generate_file_list
    list_html = ""
    grouped = @files.group_by { |f| File.dirname(f[:relative]) }
    
    grouped.each do |dir, files|
      list_html += "<h3>#{dir == '.' ? 'Root' : dir.capitalize}</h3>\n<ul>\n"
      files.each do |file|
        list_html += "<li><a href=\"#{file[:html]}\">#{file[:title]}</a></li>\n"
      end
      list_html += "</ul>\n"
    end
    
    list_html
  end

  def generate_css
    css_content = <<~CSS
      /* Patlang Documentation Styles */
      body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          margin: 0;
          padding: 0;
          display: flex;
          line-height: 1.6;
          color: #333;
      }

      .sidebar {
          width: 250px;
          background: #f8f9fa;
          padding: 20px;
          border-right: 1px solid #e9ecef;
          height: 100vh;
          overflow-y: auto;
          position: fixed;
      }

      .sidebar h2 {
          color: #495057;
          margin-top: 0;
      }

      .nav-section {
          margin-bottom: 20px;
      }

      .nav-section h3 {
          color: #6c757d;
          font-size: 14px;
          text-transform: uppercase;
          margin-bottom: 10px;
      }

      .nav-section a {
          display: block;
          color: #007bff;
          text-decoration: none;
          padding: 5px 0;
          font-size: 14px;
      }

      .nav-section a:hover {
          color: #0056b3;
          text-decoration: underline;
      }

      .content {
          margin-left: 250px;
          padding: 40px;
          max-width: 800px;
      }

      h1, h2, h3 {
          color: #343a40;
      }

      h1 {
          border-bottom: 2px solid #007bff;
          padding-bottom: 10px;
      }

      code {
          background: #f8f9fa;
          padding: 2px 4px;
          border-radius: 3px;
          font-family: 'Monaco', 'Consolas', monospace;
          font-size: 0.9em;
      }

      pre {
          background: #f8f9fa;
          border: 1px solid #e9ecef;
          border-radius: 5px;
          padding: 15px;
          overflow-x: auto;
      }

      pre code {
          background: none;
          padding: 0;
      }

      /* Patlang Syntax Highlighting */
      .language-patlang .keyword {
          color: #d73a49;
          font-weight: bold;
      }

      .language-patlang .type {
          color: #6f42c1;
          font-weight: bold;
      }

      .language-patlang .string {
          color: #032f62;
      }

      .language-patlang .number {
          color: #005cc5;
      }

      .language-patlang .comment {
          color: #6a737d;
          font-style: italic;
      }

      .language-patlang .operator {
          color: #d73a49;
      }

      table {
          border-collapse: collapse;
          width: 100%;
          margin: 20px 0;
      }

      th, td {
          border: 1px solid #e9ecef;
          padding: 8px 12px;
          text-align: left;
      }

      th {
          background: #f8f9fa;
          font-weight: bold;
      }

      blockquote {
          border-left: 4px solid #007bff;
          margin: 20px 0;
          padding-left: 20px;
          color: #6c757d;
      }
    CSS
    
    File.write(File.join(@output_dir, 'patlang-docs.css'), css_content)
  end
end

# Run the generator if called directly
if __FILE__ == $0
  generator = PatLangDocGenerator.new
  generator.generate
end
