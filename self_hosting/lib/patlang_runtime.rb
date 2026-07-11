# patlang_runtime.rb -- hand-written (not generated) Ruby runtime shim for
# PatLang's self-hosted Ruby transpiler (self_hosting/lib/transpile_ruby.
# patlang). Required by every transpiled program.
#
# Implements PatLang's v1 host-function surface for the ruby target: core
# arithmetic/numeric-tower helpers, string ops, list/vec ops, print, and
# OO object-slots. Objects are modelled as a Hash of Hash, mirroring the
# Rust runtime's own actual internal representation (OBJECTS: RefCell<
# HashMap<String, HashMap<String, Value>>> in rust-runtime/src/ir/hosts.rs)
# -- the same "closest fair equivalent" choice already used for the
# oo_events benchmark's hand-written Rust baseline.
#
# Deliberately NOT implemented (see transpile_ruby.patlang's
# ruby_unsupported_host list, which fails the transpile before any of this
# would be reached): networking, the facts/logic engine, contracts'
# underlying host call (require/ensure/assert lower to plain `raise`
# instead), meta-compilation host calls.

require "rational"
require "complex"

module PL
  OBJECTS = Hash.new { |h, k| h[k] = {} }
  EVENT_HANDLERS = Hash.new { |h, k| h[k] = [] }

  # Mirrors ir/numeric.rs's display formatting: whole floats print without
  # a trailing ".0", Rational/Complex use Ruby's own to_s (which already
  # happens to match PatLang's "num/den" / "re+imi" formatting), lists and
  # objects render recursively with sorted object keys.
  def self.display(v)
    case v
    when nil then ""
    when true then "true"
    when false then "false"
    when Integer then v.to_s
    when Float
      (v.finite? && v == v.to_i) ? v.to_i.to_s : v.to_s
    when Rational then v.to_s
    when Complex then v.to_s
    when String then v
    when Array then "[" + v.map { |x| display(x) }.join(", ") + "]"
    when Hash then "{" + v.keys.sort.map { |k| "#{k}: #{display(v[k])}" }.join(", ") + "}"
    when Proc then "<closure>"
    else v.to_s
    end
  end

  # ---- lists (list_*: copy-on-write, matching PatLang's own list_push
  # O(n)-per-call semantics) and vecs (vec_*: mutable handles) ----

  def self.list_get(l, i)
    i = i.to_i
    case l
    when Array then l[i].nil? ? nil : l[i]
    when String then l[i].nil? ? "" : l[i]
    else nil
    end
  end

  def self.list_len(l)
    case l
    when Array then l.length
    when String then l.length
    else 0
    end
  end

  def self.list_push(l, item)
    (l || []) + [item]
  end

  def self.list_set(l, i, v)
    a = l.dup
    a[i.to_i] = v
    a
  end

  def self.vec_push(v, item)
    v.push(item)
    v
  end

  def self.vec_set(v, i, x)
    v[i.to_i] = x
    v
  end

  def self.vec_get(v, i)
    v[i.to_i]
  end

  def self.vec_len(v)
    v.length
  end

  def self.vec_to_list(v)
    v
  end

  # sb_new()/sb_push(b,x)/sb_str(b) string-builder handle API.
  class StrBuilder
    def initialize
      @s = String.new
    end

    def push(x)
      @s << PL.display(x)
      self
    end

    def str
      @s
    end
  end

  def self.sb_push(b, x)
    b.push(x)
  end

  def self.sb_str(b)
    b.str
  end

  def self.str_intern(s)
    s
  end

  def self.char_code(s, i)
    s.bytes[i.to_i] || 0
  end

  def self.substr(s, i, n)
    s[i.to_i, n.to_i] || ""
  end

  def self.chr(n)
    n.to_i.chr(Encoding::UTF_8)
  end

  def self.to_num(s)
    f = s.to_f
    i = s.to_i
    f == i ? i : f
  end

  def self.hash_string(s)
    s.hash & 0x7fffffff
  end

  def self.index(obj, i)
    case obj
    when Array, String then list_get(obj, i)
    else nil
    end
  end

  # ---- OO object-slots ----

  def self.get_obj(name, prop)
    OBJECTS[name][prop]
  end

  def self.set_var(name, prop, val)
    OBJECTS[name][prop] = val
  end

  def self.new_obj(klass, name)
    OBJECTS[name]["type"] = klass
    OBJECTS[name]["name"] = name
    name
  end

  def self.send_obj(name, method, *args)
    case method
    when "set" then OBJECTS[name][args[0]] = args[1]
    when "get" then OBJECTS[name][args[0]]
    else nil
    end
  end

  def self.emit(event, payload = nil)
    EVENT_HANDLERS[event].each { |h| h.call(event, payload) }
    nil
  end

  def self.on(event, &blk)
    EVENT_HANDLERS[event] << blk
  end

  # ---- numeric tower ----

  # PatLang's `/`: exact Rational when not evenly divisible, demoted back
  # to an Integer when it is, Float if either operand is a Float. Ruby's
  # native Integer#/ truncates instead, so the transpiler routes every `/`
  # through this rather than emitting `/` directly.
  def self.div(a, b)
    if a.is_a?(Float) || b.is_a?(Float)
      a.to_f / b.to_f
    else
      r = Rational(a, b)
      r.denominator == 1 ? r.numerator : r
    end
  end

  def self.demote_whole(r)
    (r.is_a?(Float) && r.finite? && r == r.to_i) ? r.to_i : r
  end

  def self.sqrt(x)
    if x.is_a?(Numeric) && !x.is_a?(Complex) && x < 0
      Complex(0, demote_whole(Math.sqrt(-x)))
    else
      demote_whole(Math.sqrt(x))
    end
  end

  def self.type_of(x)
    case x
    when NilClass then "unit"
    when TrueClass, FalseClass then "bool"
    when Integer then "int"
    when Float then "float"
    when Rational then "rational"
    when Complex then "complex"
    when String then "string"
    when Array then "list"
    when Hash then "object"
    when Proc then "closure"
    else "object"
    end
  end

  # numeric_kind only distinguishes numeric-tower kinds (falls back to
  # "other" for everything non-numeric); type_of covers every kind.
  def self.numeric_kind(x)
    case x
    when Integer then "int"
    when Float then "float"
    when Rational then "rational"
    when Complex then "complex"
    else "other"
    end
  end

  def self.now_ms
    (Time.now.to_f * 1000).to_i
  end

  def self.read_file(path)
    File.read(path)
  end

  def self.write_file(path, content)
    File.write(path, content)
    true
  end

  def self.file_exists(path)
    File.exist?(path)
  end

  def self.host(name, _args)
    raise "transpile: host function '#{name}' has no ruby runtime shim"
  end
end
