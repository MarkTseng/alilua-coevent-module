local L = require('coevent')
local mysql = require "mysql"
local cjson = require "cjson"
local httprequest = (require "httpclient").httprequest
local cmsgpack = require('cmsgpack')

print('start')
local db = mysql:new()

local memcached = require "memcached"
local memc = memcached:new()

function test_mysql()
	local db_ok, err, errno, sqlstate = db:connect({
					host = "localhost",
					port = 3306,
					database = "d1",
					user = "u1",
					password = "u11111"})
	print('start test_mysql')
	local st = longtime()


	if not db_ok then
		print("failed to connect: ", err, ": ", errno, " ", sqlstate)
		return
	end
	print('---------------------------------------mysql connected')
	
	local res, err, errno, sqlstate =
		db:query("drop table if exists cats")
	if not res then
		print("bad result: ", err, ": ", errno, ": ", sqlstate, ".")
	end
			
	print(db:query('CREATE TABLE cats'
					.. "(id serial primary key, "
					.. "name varchar(5) NULL)"))
	if not res then
		print("bad result: ", err, ": ", errno, ": ", sqlstate, ".")
	end

	print("table cats created.")

	local res, err, errno, sqlstate =
		db:query("INSERT INTO cats ?", {
										{id=null, name='Bob'},
										{id=null, name=''},
										{id=null, name=null}
										}
				)
	 if not res then
		print("bad result: ", err, ": ", errno, ": ", sqlstate, ".")
	end
	
	res, err = db:get_results("SELECT * FROM cats")
	print(cjson.encode(res))
	
	res, err = db:get_results("SELECT * FROM cats WHERE ?", {id=123})
	print('rt', cjson.encode(res))
	
	res, err = db:query("DELETE FROM cats WHERE id=? AND name=?", 123, 'a')
	print(res, err) -- res == false
	
	res, err = db:query("DELETE FROM cats WHERE ?", {id=3, name=null})
	print(res, err) -- res == table , and res.affected_rows == 1
	
	db:query("INSERT INTO cats SET ?", {id=null, name='aa"bb'})
	db:query("INSERT INTO cats SET ?", {id=null, name="aa'bb"})
	
	res, err = db:get_results("SELECT * FROM cats")
	print('rt', cjson.encode(res))
    print('--------------------------')
	
	print('test_mysql be end  used:'..((longtime()-st)/1000));
	
	db:close()

	print('test_mysql ended')
end

function test_memcached()
	local ok, err = memc:connect("localhost", 11211)
	if not ok then
		print("failed to connect: ", err)
		return
	end
	print('---------------------------------------memcached connected')

	local ok, err = memc:flush_all()
	if not ok then
		print("failed to flush all: ", err)
		--return
	end

	print("flush: ", ok);
	
	local ok, err = memc:set("dog", 32)
	if not ok then
		print("failed to set dog: ", '['..err..']')
		return
	end

	local t = longtime()
	for i = 1, 20 do
		swop()
		local res, flags, err = memc:get("dog")
		if err then
			print("failed to get dog: ", '['..err..']')
			return
		end

		if not res then
			print("dog not found")
			return
		end

		print("dog: ", res, " (flags: ", flags, ")")
	end
	print('times:', (longtime()-t)/1000)
end

local redis = require "redis"
local red = redis:new()
function test_redis()

	red:set_timeout(1000) -- 1 sec

	local ok, err = red:connect("localhost", 6379)
	if not ok then
		print("failed to connect: ", err)
		return
	end
	print('---------------------------------------redis connected')

	local res, err = red:hmset("animals", "dog", "bark", "cat", "meow")
	if not res then
		print("failed to set animals: ", err)
		return
	end
	print("hmset animals: ", res)

	local res, err = red:hmget("animals", "dog", "cat")
	if not res then
		print("failed to get animals: ", err)
		return
	end
	for k,v in pairs(res) do print(k, v) end
	print("hmget animals: ", res)

	--red:close()
end

function test_http_client(id, host, uri)
	print('start test_http_client', id, host, uri)
	local cok = cosocket.tcp()
	local r,e = cok:connect(host, 80)
	--print(abc..'cc')

	if not r then print(1, e) return false end
	print('----------------------------------------connected!!!', id)
	
	if not uri then
		cok:send('GET / HTTP/1.1\r\nHost: '..host..'\r\nUser-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.6)\r\n')
	else
		cok:send('GET '..uri..' HTTP/1.1\r\nHost: '..host..'\r\nUser-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.6)\r\n')
	end
	
	if not cok:send('Connection: close\r\n\r\n') then print('send error') return false end
	
	local s,e,oss,oss2,oss3,oss4,kc
	kc = 0
	while 1 do
		swop()
		oss4 = oss3
		oss3 = oss2
		oss2 = oss
		oss = s
		
		s,e = cok:receive('*l')
		--s,e = cok:receive(20)
		if s then kc = kc + #s end
		--print(id, s)
		--print(id,'read ', s and #s or -1)
		if not s then 
			--print(id, e, s, kc)
		break end
	end

	if oss4 then
		oss = oss4..oss3..oss2 .. oss
		oss = oss:sub(#oss-40, #oss)
	else
		oss = ''
	end
	cok:close()
	cok = nil
--print(oss)
	print('test_http_client ended', id, (oss:find('</html>') or oss:find('2006')) and true or false, oss)
	if not e and not s then os.exit(1) end
end
--collectgarbage('stop')

local af = function()
	coroutine_wait(newthread(test_mysql))
	coroutine_wait(newthread(test_memcached))
	coroutine_wait(newthread(test_redis))
	
	--coroutine_wait(newthread(test_http_client, 0, 'docs.upyun.com', '/'))
	local t = longtime()
	--test_http_client(1, 'www.163.com') test_http_client(2, 'www.163.com') test_http_client(3, 'www.163.com')
	
	--t1 = newthread(test_http_client, 1, 'www.163.com')
	--t2 = newthread(test_http_client, 2, 'weibo.com')
	--t3 = newthread(test_http_client, 3, 'www.163.com')
	--coroutine_wait(newthread(test_http_client, 1, 'docs.upyun.com', '/'))
	local ts = {}
	for i=1,10 do swop()
		table.insert(ts, newthread(test_http_client, i+100, 'docs.upyun.com', '/'))
		--table.insert(ts, newthread(test_http_client, i+200, 'www.qq.com', '/'))
		--table.insert(ts, newthread(test_http_client, i+300, 'news.qq.com', '/'))
	end
	
	coroutine_wait(t1)
	coroutine_wait(t2)
	coroutine_wait(t3)
	
	rts,e = wait(ts)
	
	print('times:', rts, e, (longtime()-t)/1000)

	
	
	local t = longtime()
	local ts = {}
	for i=1,1 do --swop()
		print(i, coroutine_wait(newthread(test_http_client, i+100, 'docs.upyun.com', '/')))
	end
	print('times:', (longtime()-t)/1000)
	
	ts = nil
	
	
end

function test_udp_memcached()
	print('start test_udp_memcached')
	local sock = cosocket.udp()
	local req = "\0\1\0\0\0\1\0\0flush_all\r\n"
	if sock then
		print('connected: ', sock:setpeername("localhost", 11211))
		sock:settimeout(1000)  -- one second timeout
		print('sended: ', sock:send(req))
		print('sended: ', sock:send(req))
		local data, err = sock:receive()
		if not data then
			print("failed to read a packet: ", err)
		else
			print('readed: ', #data, data)
		end
		local data, err = sock:receive()
		if not data then
			print("failed to read a packet: ", err)
		else
			print('readed: ', #data, data)
		end
	end
	sock:close()
	print('test_udp_memcached ended')
end

function test_eio()
	print('mkdir', eio.mkdir('/tmp/abc'))
	print('mkdir2', eio.mkdir('/tmp/abc/a'))
	local s,en,e = eio.stat('/tmp/abc')
	print('stat', s, en, e)
	if s then
		for k,v in pairs(s) do
			--print(k,v)
		end
	end
	print('chown', eio.chown('/tmp/abc', 'dev'))
	print('chmod', eio.chmod('/tmp/abc', 766))
	print('unlink', eio.unlink('/tmp/abc'))
	print('rename', eio.rename('/tmp/abc', '/tmp/aaa'))
	print('mkdir3', eio.mkdir('/tmp/aaa/b'))
	local s,en,e = eio.readdir('/tmp/aaa/')
	print('readdir', s,en,e)
	if s then for k,v in pairs(s) do
		--print(k,v)
	end end
	print('isdir', eio.isdir('/tmp/aaa/a'))
	print('isfile', eio.isfile('coevent.so'))
	print('rmdir', eio.rmdir('/tmp/aaa/a'))
	print('rmdir', eio.rmdir('/tmp/aaa/b'))
	print('exists 1', eio.exists('/tmp/aaa'))
	print('rmdir', eio.rmdir('/tmp/aaa'))
	print('exists 2', eio.exists('/tmp/aaa'))

	local f,en,e = eio.open('/tmp/a', 'w')
	print('open', f,en,e)
	print('exists 3', eio.exists('/tmp/a'))
	if f then
		print('write', f:write('abcdefghijklmn'))
		print('write', f:write('abcdefghijklmn'))
		print('sync', f:sync())
		print('seek', f:seek(0, 'cur'))
		print('seek', f:seek(2, 'set'))
		print('seek', f:seek(0, 'cur'))
		print('read', f:read(8))
		print('seek', f:seek(0, 'end'))
		print('read', f:read(8))
		print('close', f:close())
	end

	print('unlink', eio.unlink('/tmp/a'))
end

for u = 1,1 do
	L(test_eio)
	L(af)
end

L(function()
	coroutine_wait(newthread(test_mysql))

	local res,e = httprequest('https://www.upyun.com/index.html')
	--local r,h,e = httprequest('http://www.163.com/index.html') print(r,h,e)
	if res and res.header then print(res.body) for k,v in pairs(res.header) do print(k..':',v) end end

	test_udp_memcached()
end)

print('end')
