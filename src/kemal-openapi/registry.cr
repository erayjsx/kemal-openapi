
module Kemal::OpenAPI
  # Global registry that collects all documented operations at compile time.
  # Operations are registered via the `openapi` macro at the top-level DSL.
  OPERATIONS = [] of Operation
  OPERATIONS_MAP = Hash(String, Operation).new

  # Schema registry for reusable component schemas.
  SCHEMAS = Hash(String, Schema).new

  # Security scheme registry.
  SECURITY_SCHEMES = Hash(String, SecurityScheme).new

  # Register an operation into the global registry.
  def self.register(operation : Operation)
    OPERATIONS << operation
    key = "#{operation.method.upcase} #{operation.path}"
    OPERATIONS_MAP[key] = operation
  end

  # Register a reusable schema component.
  def self.register_schema(name : String, schema : Schema)
    SCHEMAS[name] = schema
  end

  # Register a security scheme.
  def self.register_security_scheme(name : String, scheme : SecurityScheme)
    SECURITY_SCHEMES[name] = scheme
  end

  # Placeholder for macro-generated registration.
  # This will be overridden (or shadowed?) by the macro generated method?
  # Crystal doesn't support simple overriding without previous_def.
  # But if we define it here, and then macro defines it again in the same module...
  # It might error "already defined".
  # Unless we use a different name or conditionally define it?
  
  # Better: The macro generates a unique method name, and we register it?
  # Or we rely on the fact that we can append to a list of "registration procs"?
  
  # Or simpler: The macro generates `register_discovered_operations`.
  # We check if it responds to it? No.
  
  # We can just define it as empty here.
  # And use `PreviousDef` in the macro?
  # Or just let the macro define it, and ensure we call it if defined.
  # But we can't check `responds_to?` on a module easily for static methods in compiled code?
  
  # Let's try defining it here and see if macro redefinition works or errors.
  def self.register_discovered_operations
  end
end
