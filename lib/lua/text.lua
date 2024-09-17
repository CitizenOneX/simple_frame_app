-- Module to parse text strings sent from phoneside app as TxPlainText messages
_M = {}

-- Parse the TxPlainText message raw data, which is a string
function _M.parse_text(data)
	local text = {}
	text.string = data
	return text
end

return _M