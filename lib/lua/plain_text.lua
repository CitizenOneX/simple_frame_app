-- Module to parse text strings sent from phoneside app as TxPlainText messages
_M = {}

-- Parse the TxPlainText message raw data, which is a string
function _M.parse_plain_text(data)
	local plain_text = {}
	plain_text.string = data
	return plain_text
end

return _M