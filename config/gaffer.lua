--
-- Cybermon configuration file, used to tailor the behaviour of cybermon.
-- This one integrates cybermon with Gaffer, so that network events are
-- stored in Gaffer.
--

-- This file is a module, so you need to create a table, which will be
-- returned to the calling environment.  It doesn't matter what you call it.
local observer = {}

-- Other modules------------------------------------------------------------

local mime = require("mime")
local jsenc = require("json.encode")
local http = require("util.http")

-- Gaffer config -----------------------------------------------------------

-- Gaffer REST interface URL
-- Change to point at your Gaffer instance.
gaffer_base = "http://gaffer:8080/example-rest/v1"

-- GeoIP -------------------------------------------------------------------

-- Open geoip module if it exists.
local geoip
status, rtn, geoip = pcall(function() return require("geoip.country") end)
if status then
  geoip = rtn
end 

-- Open geoip database if it exists.
local geodb
if geoip then
  geodb = geoip.open()
  print("Using GeoIP: " .. tostring(geodb))
end

-- RDF URI bases -----------------------------------------------------------

local cybtype = "http://cyberprobe.sf.net/type/"
local cybprop = "http://cyberprobe.sf.net/prop/"
local cybobj = "http://cyberprobe.sf.net/obj/"

local rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
local rdfs = "http://www.w3.org/2000/01/rdf-schema#"

-- Misc functions ----------------------------------------------------------

-- Base64 encoding
local b64 = function(x)
  local a, b = mime.b64(x)
  if (a == nil) then
    return ""
  end
  return a
end

-- Gaffer support ----------------------------------------------------------

-- This uses the Gaffer schema used at:
--    https://github.com/cybermaggedon/gaffer-tools.
-- However, rather than using the Redland API, comms are direct to the Gaffer
-- REST API.

-- Add edge to observation.
-- s=source e=edge d=destination tp=type (@n or @r).
local add_edge_basic = function(edges, s, e, d, tp)

  if not edges["elements"] then
    edges["elements"] = {}
  end

  local elt = {}
  elt["directed"] = true
  elt["class"] = "gaffer.data.element.Edge"
  elt["group"] = "BasicEdge"
  elt["source"] = s
  elt["destination"] = d
  elt["properties"] = {}
  elt["properties"]["name"] = {}
  elt["properties"]["name"]["gaffer.function.simple.types.FreqMap"] = {}
  elt["properties"]["name"]["gaffer.function.simple.types.FreqMap"][tp] = 1
  elt["properties"]["name"]["gaffer.function.simple.types.FreqMap"][e] = 1

  edges["elements"][#edges["elements"] + 1] = elt

end

-- Add an edge, with object type of URI.
-- s=subject, p=predicate, o=object
local add_edge_u = function(edges, s, p, o)
  add_edge_basic(edges, "n:u:" .. s, "r:u:" .. p, "n:u:" .. o, "@r")
  add_edge_basic(edges, "n:u:" .. s, "n:u:" .. o, "r:u:" .. p, "@n")
end

-- Add an edge, with object type of string.
-- s=subject, p=predicate, o=object
local add_edge_s = function(edges, s, p, o)
  add_edge_basic(edges, "n:u:" .. s, "r:u:" .. p, "n:s:" .. o, "@r")
  add_edge_basic(edges, "n:u:" .. s, "n:s:" .. o, "r:u:" .. p, "@n")
end

-- Add an edge, with object type of integer.
-- s=subject, p=predicate, o=object
local add_edge_i = function(edges, s, p, o)
  add_edge_basic(edges, "n:u:" .. s, "r:u:" .. p, "n:i:" .. math.floor(o), "@r")
  add_edge_basic(edges, "n:u:" .. s, "n:i:" .. math.floor(o), "r:u:" .. p, "@n")
end

-- Add an edge, with object type of xsd:dateTime.
-- s=subject, p=predicate, o=object
local add_edge_dt = function(edges, s, p, o)
  add_edge_basic(edges, "n:u:" .. s, "r:u:" .. p, "n:d:" .. o, "@r")
  add_edge_basic(edges, "n:u:" .. s, "n:d:" .. o, "r:u:" .. p, "@n")
end

-- Submit a set of edges to the Gaffer REST API.
local submit_edges = function(edges)
  local c = http.http_req(gaffer_base .. "/graph/doOperation/add/elements",
  	                  "PUT", jsenc.encode(edges),
			  "application/json")
  -- Put an error to standard output, if standard HTTP response 204 not recvd
  if not (c == 204) then
    print("Gaffer REST error: status " .. c)
  end
end

-- Initialise.  This reaches out to the Gaffer instance, and stores some
-- data type information.
local init = function()

  -- Create a JSON object to submit
  edges = {}

  -- RDF type information for observation type.
  add_edge_u(edges, cybtype .. "observation", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybtype .. "observation", rdfs .. "label",
             "Observation")

  -- RDF type information for liid type.
  add_edge_u(edges, cybtype .. "liid", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybtype .. "liid", rdfs .. "label",
             "Device")

  -- RDF type information for liid type.
  add_edge_u(edges, cybprop .. "liid", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "liid", rdfs .. "label",
             "Device")

  -- RDF type definition of method property.
  add_edge_u(edges, cybprop .. "method", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "method", rdfs .. "label",
             "Method")

  -- RDF type definition of action property.
  add_edge_u(edges, cybprop .. "action", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "action", rdfs .. "label",
             "Action")

  -- RDF type definition of code property.
  add_edge_u(edges, cybprop .. "code", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "code", rdfs .. "label",
             "Response code")

  -- RDF type definition of command property.
  add_edge_u(edges, cybprop .. "command", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "command", rdfs .. "label",
             "Command")

  -- RDF type definition of status property.
  add_edge_u(edges, cybprop .. "status", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "status", rdfs .. "label",
             "Response status")

  -- RDF type definition of url property.
  add_edge_u(edges, cybprop .. "url", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "url", rdfs .. "label",
             "URL")

  -- RDF type definition of time property.
  add_edge_u(edges, cybprop .. "time", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybprop .. "time", rdfs .. "label",
             "Time of observation")

  -- RDF type definition of time property.
  add_edge_u(edges, cybprop .. "window", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybprop .. "window", rdfs .. "label",
             "Time window")

  -- Geo, country property.
  add_edge_u(edges, cybtype .. "country", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybtype .. "country", rdfs .. "label",
             "Country of origin")

  -- Geo, country property.
  add_edge_u(edges, cybprop .. "country", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybprop .. "country", rdfs .. "label",
             "Country of origin")

  -- Protocol context.
  add_edge_u(edges, cybprop .. "context", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "context", rdfs .. "label",
             "Protocol context")

  -- For DNS, DNS message type (query, answer).
  add_edge_u(edges, cybprop .. "dns_type", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "dns_type", rdfs .. "label",
             "DNS type")

  -- DNS query
  add_edge_u(edges, cybprop .. "query", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "query", rdfs .. "label",
             "DNS query")

  -- DNS answer (for a name)
  add_edge_u(edges, cybprop .. "answer_name", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "answer_name", rdfs .. "label",
             "Answer (name)")

  -- DNS answer (address)
  add_edge_u(edges, cybprop .. "answer_address", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "answer_address", rdfs .. "label",
             "Answer (address)")

  -- SMTP
  add_edge_u(edges, cybprop .. "from", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "from", rdfs .. "label",
             "From")

  add_edge_u(edges, cybprop .. "to", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "to", rdfs .. "label",
             "To")

  -- Addresses, source
  add_edge_u(edges, cybprop .. "source", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "source", rdfs .. "label",
             "Source address")

  -- Destination address
  add_edge_u(edges, cybprop .. "dest", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "dest", rdfs .. "label",
             "Destination address")

  -- ipv4 type, for ipv4 address nodes
  add_edge_u(edges, cybtype .. "ipv4", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybtype .. "ipv4", rdfs .. "label",
             "IPv4 address")

  -- tcp type, for ip:tcp nodes
  add_edge_u(edges, cybtype .. "tcp", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybtype .. "tcp", rdfs .. "label",
             "TCP port")

  -- udp type for ip:udp nodes
  add_edge_u(edges, cybtype .. "udp", rdf .. "type",
             rdfs .. "Resource")
  add_edge_s(edges, cybtype .. "udp", rdfs .. "label",
             "UDP port")

  -- port property, integer port number which is assocatiated with port object
  add_edge_u(edges, cybprop .. "port", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "port", rdfs .. "label",
             "Port number")

  -- address property, IP address associated with IP object
  add_edge_u(edges, cybprop .. "address", rdf .. "type",
             rdfs .. "Property")
  add_edge_s(edges, cybprop .. "address", rdfs .. "label",
             "Address")

  -- Send to Gaffer
  submit_edges(edges)

end

-- Observation ID, starts with 0, and is incremented.
-- FIXME: Is this right? Cyberprobe gets restarted, this will trash existing
-- observations.
local next_id = 0

-- Get next ID, increment last ID and return.
local get_next_id = function()
  local id = next_id
  next_id = next_id + 1
  return id
end

-- Gets the stack of addresses on the src/dest side of a context.
local function get_stack(context, addrs, is_src)

  local par = context:get_parent()

  if par then
    get_stack(par, addrs, is_src)
  end

  local cls, addr
  if is_src then
    cls, addr = context:get_src_addr()
  else
    cls, addr = context:get_dest_addr()
  end

  -- FIXME: This is all very IPv4-centric.

  -- IPv4 address
  if cls == "ipv4" then
    local p = {}
    p["id"] = cybobj .. "ipv4/" .. addr
    p["type"] = cybtype .. "ipv4"
    p["description"] = addr
    -- Store IPv4 address.  This allows tcp/udp addresses to lookup their IP
    -- address.
    p["ipv4"] = addr

    -- Lookup IPv4 address in GeoIP for country code.
    if geodb then
      lookup = geodb:query_by_addr(addr)
      if lookup and lookup.code and not(lookup.code == "--") then
        p["geo"] = lookup.code
      end
    end

    -- Store IPv4 protocol information in address list.
    table.insert(addrs, p)
  end

  -- TCP address
  if cls == "tcp" then
    local p = {}

    local ipv4 = "unknown"
    for i, v in ipairs(addrs) do
      if v.ipv4 then ipv4 = v.ipv4 end
    end

    p["id"] = cybobj .. "tcp/" .. ipv4 .. ":" .. addr
    p["type"] = cybtype .. "tcp"
    p["description"] = ipv4 .. ":" .. addr
    p["context"] = cybobj .. "ipv4/" .. ipv4
    p["port"] = addr
    table.insert(addrs, p)

  end

  -- UDP address
  if cls == "udp" then
    local p = {}

    local ipv4 = "unknown"
    for i, v in ipairs(addrs) do
      if v.ipv4 then ipv4 = v.ipv4 end
    end

    p["id"] = cybobj .. "udp/" .. ipv4 .. ":" .. addr
    p["type"] = cybtype .. "udp"
    p["description"] = ipv4 .. ":" .. addr
    p["context"] = cybobj .. "ipv4/" .. ipv4
    p["port"] = addr
    table.insert(addrs, p)

  end

  return addrs
end

-- Initialise a basic observation
local create_basic = function(edges, context, action)

  -- Create time string.
  local tm = context:get_event_time()
  local tmstr_s = os.date("!%Y-%m-%dT%H:%M:%S", math.floor(tm))
  local millis = 1000 * (tm - math.floor(tm))
  local tmstr = tmstr_s .. "." .. string.format("%03dZ", math.floor(millis))

  -- Just minutes, no seconds
  local window = os.date("!%Y%m%d/%H%M", math.floor(tm))

  -- Get ID
  local id = get_next_id()

  -- Get resource URI
  local uri = cybobj .. "obs/" .. context:get_liid() .. "/" .. tmstr_s .. "/" .. id

  -- URI -> observation type
  add_edge_u(edges, uri, rdf .. "type", cybtype .. "observation")

  -- LIID information
  local liid = cybobj .. "liid/" .. context:get_liid()
  add_edge_u(edges, uri, cybprop .. "liid", liid)
  add_edge_u(edges, liid, rdf .. "type", cybtype .. "liid")
  add_edge_s(edges, liid, rdfs .. "label", "Device " .. context:get_liid())

  -- Cyberprobe action type
  add_edge_s(edges, uri, cybprop .. "action", action)

  -- Store protocol stack address information: source
  addrs = {}
  get_stack(context, addrs, true)
  for key, value in pairs(addrs) do
    add_edge_u(edges, value.id, rdf .. "type", value.type)
    add_edge_s(edges, value.id, rdfs .. "label", value.description)
    if value.geo then
      add_edge_s(edges, value.id, cybprop .. "geo", value.geo)
    end
    if value.context then
      add_edge_u(edges, value.id, cybprop .. "context", value.context)
    end
    if value.ipv4 then
      add_edge_s(edges, value.id, cybprop .. "address", value.ipv4)
    end
    if value.port then
      add_edge_i(edges, value.id, cybprop .. "port", value.port)
    end
    add_edge_u(edges, uri, cybprop .. "source", value.id)
  end

  -- Store protocol stack address information: destination
  addrs = {}
  get_stack(context, addrs, false)
  for key, value in pairs(addrs) do
    add_edge_u(edges, value.id, rdf .. "type", value.type)
    add_edge_s(edges, value.id, rdfs .. "label", value.description)
    if value.geo then
      add_edge_s(edges, value.id, cybprop .. "geo", value.geo)
    end
    if value.context then
      add_edge_u(edges, value.id, cybprop .. "context", value.context)
    end
    if value.ipv4 then
      add_edge_s(edges, value.id, cybprop .. "address", value.ipv4)
    end
    if value.port then
      add_edge_i(edges, value.id, cybprop .. "port", value.port)
    end
    add_edge_u(edges, uri, cybprop .. "dest", value.id)
  end
  
  -- Time, in xsd:dateTime format
  add_edge_dt(edges, uri, cybprop .. "time", tmstr)

  -- Window (tag each observation with a time window)
  add_edge_dt(edges, uri, cybprop .. "window", window)

  return uri

end

-- This function is called when a trigger events starts collection of an
-- attacker. liid=the trigger ID, addr=trigger address
observer.trigger_up = function(e)
end

-- This function is called when an attacker goes off the air
observer.trigger_down = function(e)
end

-- This function is called when a stream-orientated connection is made
-- (e.g. TCP)
observer.connection_up = function(e)
end

-- This function is called when a stream-orientated connection is closed
observer.connection_down = function(e)
end

-- This function is called when a datagram is observed, but the protocol
-- is not recognised.
observer.unrecognised_datagram = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "unrecognised_datagram")
  add_edge_s(edges, e.id, rdfs .. "label", "unrecognised datagram")
  submit_edges(edges)
end

-- This function is called when stream data  is observed, but the protocol
-- is not recognised.
observer.unrecognised_stream = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "unrecognised_stream")
  add_edge_s(edges, id, rdfs .. "label", "unrecognised stream")
  submit_edges(edges)
end

-- This function is called when an ICMP message is observed.
observer.icmp = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "icmp")
  add_edge_s(edges, id, cybprop .. "type", e.type)
  add_edge_s(edges, id, cybprop .. "code", e.code)
  add_edge_s(edges, id, rdfs .. "label", "ICMP")
  submit_edges(edges)
end

-- This function is called when an IMAP message is observed.
observer.imap = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "imap")
  add_edge_s(edges, id, rdfs .. "label", "IMAP")
  submit_edges(edges)
end

-- This function is called when an IMAP SSL message is observed.
observer.imap_ssl = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "imap_ssl")
  add_edge_s(edges, id, rdfs .. "label", "IMAP_SSL")
  submit_edges(edges)
end

-- This function is called when a POP3 message is observed.
observer.pop3 = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "pop3")
  add_edge_s(edges, id, rdfs .. "label", "POP3")
  submit_edges(edges)
end

-- This function is called when a POP3 SSL message is observed.
observer.pop3_ssl = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "pop3_ssl")
  add_edge_s(edges, id, rdfs .. "label", "POP3_SSL")
  submit_edges(edges)
end

-- This function is called when an HTTP request is observed.
observer.http_request = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "http_request")
  add_edge_s(edges, e.id, cybprop .. "method", e.method)
  if not (e.url == nil) and not (e.url == "") then
    add_edge_u(edges, e.id, cybprop .. "url", e.url)
  end
  for key, value in pairs(e.header) do
    add_edge_s(edges, e.id, cybprop .. "header:" .. key, value)

    add_edge_u(edges, cybprop .. "header:" .. key, rdf .. "type",
               rdfs .. "Property")
    add_edge_s(edges, cybprop .. "header:" .. key, rdfs .. "label",
               key)

  end
--  if (body and not body == "") then
--    add_edge_s(edges, e.id, cybprop .. "body", b64(body))
--  end
  if url == nil then
    url = ""
  end
  add_edge_s(edges, e.id, rdfs .. "label", "HTTP " .. method .. " " .. url)
  submit_edges(edges)
end

-- This function is called when an HTTP response is observed.
observer.http_response = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "http_response")
  add_edge_s(edges, e.id, cybprop .. "code", e.code)
  add_edge_s(edges, e.id, cybprop .. "status", e.status)
  if not (e.url == nil) and not (e.url == "") then
    add_edge_u(edges, e.id, cybprop .. "url", e.url)
  end
  for key, value in pairs(e.header) do
    add_edge_s(edges, e.id, cybprop .. "header:" .. key, value)

    add_edge_u(edges, cybprop .. "header:" .. key, rdf .. "type",
               rdfs .. "Property")
    add_edge_s(edges, cybprop .. "header:" .. key, rdfs .. "label",
               key)

  end
  if e.url == nil then
    url = e.""
  end
  add_edge_s(edges, e.id, rdfs .. "label",
             "HTTP " .. code .. " " .. e.status .. " " .. e.url)
  submit_edges(edges)
end

-- This function is called when a DNS message is observed.
observer.dns_message = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "dns_message")

  local label = "DNS"
  
  if e.header.qr == 0 then
    add_edge_s(edges, e.id, cybprop .. "dns_type", "query")
    label = "DNS query"
  else
    add_edge_s(edges, e.id, cybprop .. "dns_type", "answer")
    label = "DNS answer"
  end

  for key, value in pairs(e.queries) do
    add_edge_s(edges, e.id, cybprop .. "query", value.name)
    label = label .. " " .. value.name
  end

  for key, value in pairs(e.answers) do
    add_edge_s(edges, e.id, cybprop .. "answer_name", value.name)
    if value.rdaddress then
       add_edge_s(edges, e.id, cybprop .. "answer_address",
                  value.rdaddress)
    end
    if value.rdname then
       add_edge_s(edges, e.id, cybprop .. "answer_name",
                            value.rdname)
    end
  end

  add_edge_s(edges, e.id, rdfs .. "label", label)

  submit_edges(edges)
end


-- This function is called when an FTP command is observed.
observer.ftp_command = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "ftp_command")
  add_edge_s(edges, e.id, cybprop .. "command", e.command)
  add_edge_s(edges, e.id, rdfs .. "label", "FTP " .. e.command)
  submit_edges(edges)
end

-- This function is called when an FTP response is observed.
observer.ftp_response = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "ftp_response")
  add_edge_s(edges, e.id, cybprop .. "status", e.status)
  local t = ""
  for k, v in ipairs(e.text) do
    if not (t == "") then
      t = t .. " "
    end
    t = t .. v
  end
  add_edge_s(edges, e.id, cybprop .. "text", t)
  add_edge_s(edges, e.id, rdfs .. "label", "FTP " .. e.status)
  submit_edges(edges)
end

-- This function is called when a SIP request message is observed.
observer.sip_request = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "sip_request")
  add_edge_s(edges, e.id, cybprop .. "method", method)
  add_edge_s(edges, e.id, cybprop .. "from", from)
  add_edge_s(edges, e.id, cybprop .. "to", to)
  add_edge_s(edges, e.id, rdfs .. "label", "SIP request")
  submit_edges(edges)
end

-- This function is called when a SIP response message is observed.
observer.sip_response = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "sip_response")
  add_edge_s(edges, e.id, cybprop .. "code", e.code)
  add_edge_s(edges, e.id, cybprop .. "status", e.status)
  add_edge_s(edges, e.id, cybprop .. "from", e.from)
  add_edge_s(edges, e.id, cybprop .. "to", e.to)
  add_edge_s(edges, e.id, rdfs .. "label", "SIP response")
  submit_edges(edges)
end

-- This function is called when a SIP SSL message is observed.
observer.sip_ssl = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "sip_ssl")
  add_edge_s(edges, e.id, rdfs .. "label", "SIP SSL")
  submit_edges(edges)
end

-- This function is called when an SMTP command is observed.
observer.smtp_command = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "smtp_command")
  add_edge_s(edges, e.id, cybprop .. "command", e.command)
  add_edge_s(edges, e.id, rdfs .. "label", "SMTP " .. e.command)
  submit_edges(edges)
end

-- This function is called when an SMTP response is observed.
observer.smtp_response = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "smtp_response")
  add_edge_s(edges, e.id, cybprop .. "status", e.status)
  local t = ""
  for k, v in ipairs(e.text) do
    if not (t == "") then
      t = t .. " "
    end
    t = t .. v
  end
  add_edge_s(edges, e.id, cybprop .. "text", t)
  add_edge_s(edges, e.id, rdfs .. "label", "SMTP " .. e.status)
  submit_edges(edges)
end

-- This function is called when an SMTP response is observed.
observer.smtp_data = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "smtp_data")
  add_edge_s(edges, e.id, cybprop .. "from", e.from)
  local t = ""
  for k, v in ipairs(e.to) do
    if not (t == "") then
      t = t .. " "
    end
    t = t .. v
    add_edge_s(edges, e.id, cybprop .. "to", v)
  end
  add_edge_s(edges, e.id, rdfs .. "label", "SMTP " .. from .. " " .. t)
  submit_edges(edges)
end

-- This function is called when an NTP timestamp message is observed.
observer.ntp_timestamp_message = function(e)
end

-- This function is called when an NTP control message is observed.
observer.ntp_control_message = function(e)
end

-- This function is called when an NTP private message is observed.
observer.ntp_private_message = function(e)
end

-- This function is called when a gre message is observed.
observer.gre = function(e)
end

-- This function is called when a grep pptp message is observed.
observer.grep_pptp = function(e)
end

-- This function is called when an esp message is observed.
observer.esp = function(e)
end

-- This function is called when an unrecognised ip protocol message is observed.
observer.unrecognised_ip_protocol = function(e)
  local edges = {}
  local id = create_basic(edges, e.context, "unrecognised_ip")
  add_edge_s(edges, id, rdfs .. "label", "unrecognised ip")
  submit_edges(edges)
end

-- This function is called when an 802.11 message is observed.
observer.wlan = function(e)
end

-- This function is called when an unknown tls message is observed.
observer.tls_unknown = function(e)
end

-- This function is called when a tls client hello message is observed.
observer.tls_client_hello = function(e)
end

-- This function is called when a tls server hello message is observed.
observer.tls_server_hello = function(e)
end

-- This function is called when a tls certificates message is observed.
observer.tls_certificates = function(e)
end

-- This function is called when a tls server key exchange message is observed.
observer.tls_server_key_exchange = function(e)
end

-- This function is called when a tls server hello done message is observed.
observer.tls_server_hello_done = function(e)
end

-- This function is called when an unknown tls handshake message is observed.
observer.tls_handshake_unknown = function(e)
end

-- This function is called when a tls certificate request message is observed.
observer.tls_certificate_request = function(e)
end

-- This function is called when a tls client_key exchange message is observed.
observer.tls_client_key_exchange = function(e)
end

-- This function is called when a tls certificate verify message is observed.
observer.tls_certificate_verify = function(e)
end

-- This function is called when a tls change cipher spec message is observed.
observer.tls_change_cipher_spec = function(e)
end

-- This function is called when a tls handshake finished message is observed.
observer.tls_handshake_finished = function(e)
end

-- This function is called when both sides of the handshake have finished.
observer.tls_handshake_complete = function(e)
end

-- This function is called when a tls application data message is observed.
observer.tls_application_data = function(e)
end


-- Initialise
init()

-- Return the table
return observer

