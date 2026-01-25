-- =============================================================================
-- Custom Kong Lua Plugin: Request Handler
-- =============================================================================
--
-- Key Concept: Kong Plugin Development
-- -------------------------------------
-- Kong plugins are written in Lua and can hook into various phases of the
-- request/response lifecycle:
--
-- 1. init_worker     - Called when Kong worker starts
-- 2. certificate     - Called during SSL certificate request
-- 3. rewrite         - Before routing (can change upstream)
-- 4. access          - After routing, before proxying (auth, rate limiting)
-- 5. response        - After receiving upstream response headers
-- 6. header_filter   - Before sending response headers to client
-- 7. body_filter     - Before sending response body to client
-- 8. log             - After response is sent (logging, metrics)
--
-- This Plugin Features:
-- ---------------------
-- 1. Custom request header injection (X-Custom-Request-Id)
-- 2. Request timing measurement
-- 3. Structured JSON logging
-- 4. Custom response header injection
-- 5. Request/Response body size tracking
--

-- Import Kong's plugin base
local BasePlugin = require "kong.plugins.base_plugin"
local kong = kong

-- Create plugin class
local CustomRequestHandler = BasePlugin:extend()

-- Plugin priority (higher = runs earlier)
-- JWT plugin has priority 1005, rate-limiting has 901
-- We want this to run early but after authentication
CustomRequestHandler.PRIORITY = 800
CustomRequestHandler.VERSION = "1.0.0"

-- Plugin name (for logging)
function CustomRequestHandler:new()
  CustomRequestHandler.super.new(self, "custom-request-handler")
end

-- =============================================================================
-- ACCESS Phase
-- =============================================================================
-- Called after routing and before sending request to upstream.
-- Perfect for:
-- - Adding request headers
-- - Request validation
-- - Custom authentication logic
-- - Request transformation

function CustomRequestHandler:access(conf)
  CustomRequestHandler.super.access(self)
  
  -- Generate unique request ID for tracing
  local request_id = kong.request.get_header("X-Request-ID")
  if not request_id then
    -- Generate a UUID-like ID if not provided
    request_id = string.format("%s-%s-%d", 
      os.date("%Y%m%d%H%M%S"),
      string.sub(tostring({}):gsub("table: ", ""), 1, 8),
      math.random(1000, 9999)
    )
  end
  
  -- Store request start time for measuring duration
  kong.ctx.plugin.request_start_time = ngx.now()
  kong.ctx.plugin.request_id = request_id
  
  -- Add custom headers to request sent to upstream
  kong.service.request.set_header("X-Custom-Request-Id", request_id)
  kong.service.request.set_header("X-Gateway-Timestamp", os.date("%Y-%m-%dT%H:%M:%SZ"))
  
  -- Add original client IP header (useful when behind load balancer)
  local client_ip = kong.client.get_ip()
  kong.service.request.set_header("X-Real-Client-IP", client_ip)
  
  -- Add forwarded headers for upstream service awareness
  kong.service.request.set_header("X-Forwarded-For", client_ip)
  kong.service.request.set_header("X-Forwarded-Host", kong.request.get_host())
  kong.service.request.set_header("X-Forwarded-Proto", kong.request.get_scheme())
  
  -- Custom header from plugin configuration
  if conf.custom_header_name and conf.custom_header_value then
    kong.service.request.set_header(conf.custom_header_name, conf.custom_header_value)
  end
  
  -- Log the incoming request (structured format)
  if conf.enable_logging then
    kong.log.info(string.format(
      "[REQUEST] id=%s method=%s path=%s client_ip=%s",
      request_id,
      kong.request.get_method(),
      kong.request.get_path(),
      client_ip
    ))
  end
end

-- =============================================================================
-- HEADER_FILTER Phase
-- =============================================================================
-- Called before response headers are sent to the client.
-- Perfect for:
-- - Adding response headers
-- - Modifying response headers
-- - Setting cache headers

function CustomRequestHandler:header_filter(conf)
  CustomRequestHandler.super.header_filter(self)
  
  -- Calculate request duration
  local start_time = kong.ctx.plugin.request_start_time
  local duration_ms = 0
  if start_time then
    duration_ms = math.floor((ngx.now() - start_time) * 1000)
  end
  
  -- Add custom response headers
  kong.response.set_header("X-Custom-Request-Id", kong.ctx.plugin.request_id or "unknown")
  kong.response.set_header("X-Response-Time-Ms", tostring(duration_ms))
  kong.response.set_header("X-Gateway-Version", "Kong-Custom-Plugin-1.0.0")
  
  -- Add security headers (defense in depth)
  if conf.add_security_headers then
    kong.response.set_header("X-Content-Type-Options", "nosniff")
    kong.response.set_header("X-Frame-Options", "DENY")
    kong.response.set_header("X-XSS-Protection", "1; mode=block")
  end
  
  -- Store duration for logging phase
  kong.ctx.plugin.request_duration_ms = duration_ms
end

-- =============================================================================
-- LOG Phase
-- =============================================================================
-- Called after the response is sent to the client.
-- Perfect for:
-- - Logging requests/responses
-- - Sending metrics to external systems
-- - Auditing
--
-- IMPORTANT: Cannot modify request/response in this phase

function CustomRequestHandler:log(conf)
  CustomRequestHandler.super.log(self)
  
  if not conf.enable_logging then
    return
  end
  
  -- Gather log data
  local request_id = kong.ctx.plugin.request_id or "unknown"
  local duration_ms = kong.ctx.plugin.request_duration_ms or 0
  
  local log_data = {
    -- Request info
    request_id = request_id,
    method = kong.request.get_method(),
    path = kong.request.get_path(),
    query = kong.request.get_raw_query(),
    host = kong.request.get_host(),
    
    -- Client info
    client_ip = kong.client.get_ip(),
    consumer = kong.client.get_consumer() and kong.client.get_consumer().username or "anonymous",
    
    -- Response info
    status = kong.response.get_status(),
    duration_ms = duration_ms,
    
    -- Service info
    service = kong.router.get_service() and kong.router.get_service().name or "unknown",
    route = kong.router.get_route() and kong.router.get_route().name or "unknown",
    
    -- Timestamp
    timestamp = os.date("%Y-%m-%dT%H:%M:%SZ")
  }
  
  -- Create structured log message
  local log_message = string.format(
    "[RESPONSE] id=%s status=%d duration=%dms method=%s path=%s client=%s service=%s",
    log_data.request_id,
    log_data.status,
    log_data.duration_ms,
    log_data.method,
    log_data.path,
    log_data.client_ip,
    log_data.service
  )
  
  -- Log based on status code
  if log_data.status >= 500 then
    kong.log.err(log_message)
  elseif log_data.status >= 400 then
    kong.log.warn(log_message)
  else
    kong.log.info(log_message)
  end
  
  -- Optional: Log full JSON for structured logging systems
  if conf.log_full_json then
    local cjson = require "cjson.safe"
    kong.log.info("[JSON_LOG] " .. (cjson.encode(log_data) or "encoding_error"))
  end
end

-- Return the plugin
return CustomRequestHandler

