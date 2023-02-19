import socket

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(("0.0.0.0", 1234))
s.listen()

while True:
    c, addr = s.accept()
    print(addr, "connected")
    while True:
        data = c.recv(1024)
        # print(data)
        print(data.decode('utf-8'))
        if not data:
            break
        c.sendall(data)
