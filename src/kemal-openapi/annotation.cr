
module Kemal::OpenAPI
  # Annotation for defining OpenAPI operations on routes.
  #
  # Usage:
  # ```crystal
  # @[OpenAPI(summary: "List users", tags: ["Users"])]
  # get "/users" do ... end
  # ```
  annotation OpenAPI
  end

  # Internal annotation used by macros to track route metadata.
  annotation Internal
  end
end

# Alias for top-level usage
annotation OpenAPI
end
