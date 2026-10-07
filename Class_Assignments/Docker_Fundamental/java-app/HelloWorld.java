import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

// Hello World web server using the JDK's built-in HttpServer (no frameworks).
public class HelloWorld {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/", exchange -> {
            String html = "<!DOCTYPE html><html><head><title>Java app</title></head>"
                + "<body style=\"font-family:sans-serif;text-align:center;margin-top:15%\">"
                + "<h1>Hello World</h1><p>from a Java " + System.getProperty("java.version") + " container</p>"
                + "</body></html>";
            byte[] body = html.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/html");
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream os = exchange.getResponseBody()) { os.write(body); }
        });
        server.start();
        System.out.println("Java app listening on port 8080");
    }
}
