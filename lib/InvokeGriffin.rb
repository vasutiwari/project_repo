require "rubygems"
require 'java'
require 'digest/md5'
require 'openssl'
require 'base64'
require 'net/https'
require 'digest/sha1'
require 'cgi'
require 'rexml/document'
include_class 'java.security.MessageDigest'


# Definition section for qry and location.
return nil if ARGV[0].nil?
vStr = ARGV[0] #"select * from #{ARGV[0]} FOR XML RAW"
path = ARGV[1] ||= 'https://www.yardiasptx10.com/90319griffin/pages/iExtAdhoc.aspx'
http = Net::HTTP.new('www.yardiasptx10.com', 443)
http.use_ssl = true
resp, data = http.get(path, nil)
cookie = resp.response['set-cookie']
sessionId = resp.response['set-cookie'].split(";")[0].split("=")[1]

vPhrase="41t81u4bzyqhzfnxlvnq8zxt64kzgkhpr2hiowrcn0erng2897b1w1luu58a4lwqf35j36fm1a2sbqp9v8y2j295igwbrmjr3dskq73nobptyrdjkjm37cv66gjlfv72reguehqocm44ms1kxj1dudkgthxmtxu3fpuw2iey0mr5a3ollkoeinyhhslnhyi43pivpjs0onffx4cw9ucovomius9x596eqq67dtg1cx3gle0vxwzpkpasitvysatf41t81u4bzyqhzfnxlvnq8zxt64kzgkhpr2hiowrcn0erng2897b1w1luu58a4lwqf35j36fm1a2sbqp9v8y2j295igwbrmjr3dskq73nobptyrdjkjm37cv66gjlfv72reguehqocm44ms1kxj1dudkgthxmtxu3fpuw2iey0mr5a3ollkoeinyhhslnhyi43pivpjs0onffx4cw9ucovomius9x596eqq67dtg1cx3gle0vxwzpkpasitvysatf"+sessionId

pKey = Array.new(32)
pIV = Array.new(16)
pSHA384 = MessageDigest.get_instance "SHA-384"
pHash = pSHA384.digest(vPhrase.to_java_bytes)
#Create the Key and IV from the Phrase
pHash.each_with_index do |pByte, i|
        if i < 32 then
                pKey[i] = pByte
        elsif i < 48
                pIV[i-32] = pByte
        end
end
pEncryptedString = ""
pSSL = OpenSSL::Cipher::Cipher.new("AES-256-CBC")
pSSL.encrypt
pSSL.padding = 1
pSSL.key = pKey.pack("c*")
pSSL.iv = pIV.pack("c*")
pEncryptedString = pSSL.update(vStr)
pEncryptedString << pSSL.final
pEncryptedString = Base64.encode64(pEncryptedString)
pEncryptedString=CGI::escape(pEncryptedString)

data = "q="+pEncryptedString
headers = {
  'Cookie' => cookie,
  'ASP.NET_SessionId' => sessionId,
  'Referer' => 'https://www.yardiasptx10.com/90319griffin/pages/iExtAdhoc.aspx',
  'Content-Type' => 'application/x-www-form-urlencoded'
}

resp, data = http.post(path, data, headers)
resp = "<ROOT>" + resp.body + "</ROOT>"
a=File.new(File.dirname(__FILE__) + "/../GriffinResponse.xml", 'w')
a.write(resp)
a.close
