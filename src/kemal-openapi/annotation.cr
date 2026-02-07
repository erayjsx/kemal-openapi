module Kemal::OpenAPI
  # Global registry that collects all documented operations at compile time.
  # Operations are registered via the `openapi` macro at the top-level DSL.
  OPERATIONS = [] of Operation

  # Schema registry for reusable component schemas.
  SCHEMAS = Hash(String, Schema).new

  # Security scheme registry.
  SECURITY_SCHEMES = Hash(String, SecurityScheme).new

  # Register an operation into the global registry.
  def self.register(operation : Operation)
    OPERATIONS << operation
  end

  # Register a reusable schema component.
  def self.register_schema(name : String, schema : Schema)
    SCHEMAS[name] = schema
  end

  # Register a security scheme.
  def self.register_security_scheme(name : String, scheme : SecurityScheme)
    SECURITY_SCHEMES[name] = scheme
  end
end
