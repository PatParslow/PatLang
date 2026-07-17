# PatLang Standard Library - HTTP Module
# HTTP client and server functionality
# Foreign functions implemented in C runtime

import "core.pat"
import "io.pat"

# ============================================================================
# HTTP SERVER
# ============================================================================

make a class called HttpServer inherits BaseObject {
  make a function called initialize { takes: port, handler }
  make a function called start { }
  make a function called stop { }
  make a function called is_running { }
  make a function called port { }
}

# ============================================================================
# HTTP REQUEST
# ============================================================================

make a class called HttpRequest inherits BaseObject {
  make a function called method { }
  make a function called path { }
  make a function called headers { }
  make a function called body { }
  make a function called query_params { }
  make a function called url { }
}

# ============================================================================
# HTTP RESPONSE
# ============================================================================

make a class called HttpResponse inherits BaseObject {
  make a function called initialize { takes: status, headers?, body? }
  make a function called status { }
  make a function called headers { }
  make a function called body { }
  make a function called set_header { takes: name, value }
  make a function called write { takes: data }
  make a function called to_string { }
}

# ============================================================================
# TCP LISTENER (low-level)
# ============================================================================

make a class called TcpListener inherits BaseObject {
  make a function called initialize { takes: port }
  make a function called accept { }
  make a function called close { }
  make a function called port { }
}

make a class called TcpStream inherits BaseObject {
  make a function called read { takes: size }
  make a function called write { takes: data }
  make a function called flush { }
  make a function called close { }
  make a function called peer_address { }
}

# ============================================================================
# HTTP CLIENT
# ============================================================================

make a class called HttpClient inherits BaseObject {
  make a function called get { takes: url, headers? }
  make a function called post { takes: url, body?, headers? }
  make a function called put { takes: url, body?, headers? }
  make a function called delete { takes: url, headers? }
  make a function called request { takes: method, url, body?, headers? }
}

# ============================================================================
# HTTP ROUTER
# ============================================================================

make a class called HttpRouter inherits BaseObject {
  make a function called initialize { }
  make a function called get { takes: path, handler }
  make a function called post { takes: path, handler }
  make a function called put { takes: path, handler }
  make a function called delete { takes: path, handler }
  make a function called handle { takes: request }
}

# ============================================================================
# GLOBAL CONSTRUCTORS
# ============================================================================

make a class called Http inherits BaseObject {
  make a function called server { takes: port, handler }
  make a function called client { }
  make a function called router { }
}