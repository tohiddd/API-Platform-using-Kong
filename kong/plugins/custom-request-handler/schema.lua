-- =============================================================================
-- Custom Kong Lua Plugin: Schema Definition
-- =============================================================================
--
-- Key Concept: Kong Plugin Schema
-- --------------------------------
-- The schema defines the configuration options for your plugin.
-- Kong uses this to:
-- 1. Validate configuration values
-- 2. Provide default values
-- 3. Document available options
--
-- Schema Structure:
-- - name: Plugin name (must match directory name)
-- - fields: Array of configuration fields
-- - entity_checks: Custom validation logic
--

local typedefs = require "kong.db.schema.typedefs"

return {
  -- Plugin name (must match directory name)
  name = "custom-request-handler",
  
  -- Configuration fields
  fields = {
    -- Standard Kong plugin fields
    { consumer = typedefs.no_consumer },  -- Plugin doesn't need consumer binding
    { protocols = typedefs.protocols_http },  -- HTTP/HTTPS only
    { config = {
        type = "record",
        fields = {
          -- ===========================================
          -- Logging Configuration
          -- ===========================================
          
          -- Enable/disable request logging
          {
            enable_logging = {
              type = "boolean",
              default = true,
              description = "Enable structured request/response logging"
            }
          },
          
          -- Log full JSON payload
          {
            log_full_json = {
              type = "boolean",
              default = false,
              description = "Include full JSON log for structured logging systems"
            }
          },
          
          -- ===========================================
          -- Header Configuration
          -- ===========================================
          
          -- Add security headers to responses
          {
            add_security_headers = {
              type = "boolean",
              default = true,
              description = "Add security headers (X-Content-Type-Options, X-Frame-Options, etc.)"
            }
          },
          
          -- Custom header name (request to upstream)
          {
            custom_header_name = {
              type = "string",
              default = "X-Custom-Plugin",
              description = "Custom header name to add to requests"
            }
          },
          
          -- Custom header value
          {
            custom_header_value = {
              type = "string",
              default = "enabled",
              description = "Value for the custom header"
            }
          },
          
          -- ===========================================
          -- Request Validation (Optional Features)
          -- ===========================================
          
          -- Required headers (comma-separated list)
          {
            required_headers = {
              type = "string",
              default = nil,
              description = "Comma-separated list of required headers"
            }
          },
          
          -- Block requests without User-Agent
          {
            block_empty_user_agent = {
              type = "boolean",
              default = false,
              description = "Block requests that don't have a User-Agent header"
            }
          },
          
          -- Minimum request body size (bytes)
          {
            min_body_size = {
              type = "integer",
              default = 0,
              description = "Minimum request body size in bytes (0 = no minimum)"
            }
          },
          
          -- Maximum request body size (bytes)
          {
            max_body_size = {
              type = "integer",
              default = 0,
              description = "Maximum request body size in bytes (0 = no limit)"
            }
          },
        },
      },
    },
  },
  
  -- Entity checks (cross-field validation)
  entity_checks = {
    -- Ensure min <= max body size
    {
      custom_entity_check = {
        field_sources = { "config.min_body_size", "config.max_body_size" },
        fn = function(entity)
          local min = entity.config.min_body_size or 0
          local max = entity.config.max_body_size or 0
          
          if min > 0 and max > 0 and min > max then
            return nil, "min_body_size cannot be greater than max_body_size"
          end
          
          return true
        end
      }
    }
  }
}

