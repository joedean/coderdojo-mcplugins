package com.coderdojo.mcplugins;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;

import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.RubyRuntimeAdapter;
import org.jruby.javasupport.JavaEmbedUtils;

public class Main {
    public static String getVersion() throws IOException {
        return getResourceLine("VERSION");
    }

    public static String getForgeVersion() throws IOException {
        return getResourceLine("FORGE_VERSION");
    }

    public static void main(String[] args) throws IOException {
        RubyInstanceConfig config = new RubyInstanceConfig();
        config.setArgv(args);
        Ruby runtime = JavaEmbedUtils.initialize(new ArrayList(), config);
        RubyRuntimeAdapter evaler = JavaEmbedUtils.newRuntimeAdapter();

        try {
            evalScript("bubblebabble.rb", runtime, evaler);
            evalScript("coderdojo.rb", runtime, evaler);
            evalScript("check_environment.rb", runtime, evaler);
        } finally {
            JavaEmbedUtils.terminate(runtime);
        }
    }

    public static void saveFile(String resource, String path) throws IOException {
        File file = new File(path);
        InputStream input = Main.class.getResourceAsStream(resource);

        try {
            FileOutputStream output = new FileOutputStream(file);

            try {
                byte[] buffer = new byte[1024];
                int length;

                while ((length = input.read(buffer)) > 0) {
                    output.write(buffer, 0, length);
                }
            } finally {
                output.close();
            }
        } finally {
            input.close();
        }
    }

    private static void evalScript(String script, Ruby runtime, RubyRuntimeAdapter evaler) throws IOException {
        InputStream stream = null;

        try {
            stream = Main.class.getResourceAsStream(script);
            evaler.parse(runtime, stream, script, 0).run();
        } finally {
            if (stream != null) {
                stream.close();
            }
        }
    }

    private static String getResourceLine(String resource) throws IOException {
        BufferedReader input = new BufferedReader(new InputStreamReader(Main.class.getResourceAsStream(resource)));

        try {
            return input.readLine().trim();
        } finally {
            input.close();
        }
    }
}
