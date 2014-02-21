package com.coderdojo.mcplugins;

import java.io.InputStream;
import java.io.IOException;
import java.util.ArrayList;

import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.RubyRuntimeAdapter;
import org.jruby.javasupport.JavaEmbedUtils;

public class Main {
    public static void main(String[] args) throws IOException {
        RubyInstanceConfig config = new RubyInstanceConfig();
        config.setArgv(args);
        Ruby runtime = JavaEmbedUtils.initialize(new ArrayList(), config);
        RubyRuntimeAdapter evaler = JavaEmbedUtils.newRuntimeAdapter();

        try {
            evalScript("check_environment.rb", runtime, evaler);
        } finally {
            JavaEmbedUtils.terminate(runtime);
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
}
