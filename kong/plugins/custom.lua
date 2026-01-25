-- =============================================================================
-- Custom Kong Lua Plugin: Simplified Version
-- =============================================================================
--
-- This is a simplified single-file version of the custom plugin
-- that can be easily loaded via Kong's custom plugin mechanism.
--
-- Features:
-- 1. Request ID generation and injection
-- 2. Request timing measurement
-- 3. Structured logging
-- 4. Custom response headers
-- 5. Security headers
--
-- Key Concept: Kong PDK (Plugin Development Kit)
-- -----------------------------------------------
-- Kong provides a Lua library for plugin development:
-- - kong.request.*   : Access request data
-- - kong.response.*  : Set response headers/body
-- - kong.service.*   : Modify upstream request
-- - kong.client.*    : Get client information
-- - kong.log.*       : Logging utilities
-- - kong.ctx.*       : Request-scoped context
--

local kong = kong

-- Plugin table
local CustomPlugin = {
  PRIORITY = 800,     -- Plugin priority (lower = runs later)
  VERSION = "1.0.0",  -- Plugin version
}

-- =============================================================================
-- Helper Functions
-- =============================================================================

--- Generate a unique request ID
-- @return string Unique request identifier
local function generate_request_id()
  return string.format(
    "%s-%08x-%04x",
    os.date("%Y%m%d%H%M%S"),
    math.random(0, 0xFFFFFFFF),
    math.random(0, 0xFFFF)
  )
end

--- Get client's real IP (handles proxies)
-- @return string Client IP address
local function get_real_client_ip()
  -- Check X-Forwarded-For header first
  local forwarded_for = kong.request.get_header("X-Forwarded-For")
  if forwarded_for then
    -- Get first IP in the list (original client)
    local first_ip = forwarded_for:match("^([^,]+)")
    if first_ip then
      return first_ip:gsub("%s+", "")
    end
  end
  
  -- Fall back to Kong's client IP
  return kong.client.get_ip()
end

--- Create structured log entry
-- @param request_id string Request identifier
-- @param phase string Request phase (access/log)
-- @param data table Additional log data
-- @return string Formatted log message
local function create_log_entry(request_id, phase, data)
  local parts = {
    "[" .. phase:upper() .. "]",
    "id=" .. (request_id or "unknown"),
  }
  
  for k, v in pairs(data or {}) do
    table.insert(parts, k .. "=" .. tostring(v))
  end
  
  return table.concat(parts, " ")
end

-- =============================================================================
-- ACCESS Phase Handler
-- =============================================================================
-- Called after routing, before sending request to upstream

function CustomPlugin:access(conf)
  -- Get or generate request ID
  local request_id = kong.request.get_header("X-Request-ID")
  if not request_id or request_id == "" then
    request_id = generate_request_id()
  end
  
  -- Store in context for later phases
  kong.ctx.plugin.request_id = request_id
  kong.ctx.plugin.start_time = ngx.now()
  
  -- Get client IP
  local client_ip = get_real_client_ip()
  kong.ctx.plugin.client_ip = client_ip
  
  -- Add headers to upstream request
  kong.service.request.set_header("X-Request-ID", request_id)
  kong.service.request.set_header("X-Real-IP", client_ip)
  kong.service.request.set_header("X-Gateway-Time", os.date("!%Y-%m-%dT%H:%M:%SZ"))
  
  -- Add custom header if configured
  if conf and conf.custom_header_name and conf.custom_header_value then
    kong.service.request.set_header(conf.custom_header_name, conf.custom_header_value)
  end
  
  -- Log request (if enabled)
  if not conf or conf.enable_logging ~= false then
    local log_data = {
      method = kong.request.get_method(),
      path = kong.request.get_path(),
      client_ip = client_ip,
      host = kong.request.get_host(),
    }
    kong.log.info(create_log_entry(request_id, "request", log_data))
  end
end

-- =============================================================================
-- HEADER_FILTER Phase Handler
-- =============================================================================
-- Called before response headers are sent to client

function CustomPlugin:header_filter(conf)
  -- Get stored context
  local request_id = kong.ctx.plugin.request_id
  local start_time = kong.ctx.plugin.start_time
  
  -- Calculate duration
  local duration_ms = 0
  if start_time then
    duration_ms = math.floor((ngx.now() - start_time) * 1000)
  end
  kong.ctx.plugin.duration_ms = duration_ms
  
  -- Add response headers
  if request_id then
    kong.response.set_header("X-Request-ID", request_id)
  end
  kong.response.set_header("X-Response-Time", tostring(duration_ms) .. "ms")
  kong.response.set_header("X-Powered-By", "Kong-Custom-Plugin")
  
  -- Add security headers (if enabled)
  if not conf or conf.add_security_headers ~= false then
    kong.response.set_header("X-Content-Type-Options", "nosniff")
    kong.response.set_header("X-Frame-Options", "SAMEORIGIN")
    kong.response.set_header("X-XSS-Protection", "1; mode=block")
    kong.response.set_header("Referrer-Policy", "strict-origin-when-cross-origin")
  end
end

-- =============================================================================
-- LOG Phase Handler
-- =============================================================================
-- Called after response is sent to client (for logging/metrics)

function CustomPlugin:log(conf)
  -- Skip if logging disabled
  if conf and conf.enable_logging == false then
    return
  end
  
  -- Get stored context
  local request_id = kong.ctx.plugin.request_id
  local client_ip = kong.ctx.plugin.client_ip
  local duration_ms = kong.ctx.plugin.duration_ms or 0
  
  -- Get route and service info
  local route = kong.router.get_route()
  local service = kong.router.get_service()
  
  -- Create log entry
  local log_data = {
    status = kong.response.get_status(),
    duration_ms = duration_ms,
    method = kong.request.get_method(),
    path = kong.request.get_path(),
    client_ip = client_ip,
    route = route and route.name or "unknown",
    service = service and service.name or "unknown",
  }
  
  -- Get consumer info if authenticated
  local consumer = kong.client.get_consumer()
  if consumer then
    log_data.consumer = consumer.username or consumer.custom_id or "unknown"
  end
  
  -- Log based on status code severity
  local log_message = create_log_entry(request_id, "response", log_data)
  local status = log_data.status
  
  if status >= 500 then
    kong.log.err(log_message)
  elseif status >= 400 then
    kong.log.warn(log_message)
  else
    kong.log.info(log_message)
  end
end

-- Return the plugin
return CustomPlugin

