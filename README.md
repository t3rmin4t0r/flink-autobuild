# flink-autobuild

An easy way to build Flink-on-Tez for dev purposes

    $ make dist install
    $ ./dist/flink/flink-tez org.apache.flink.tez.examples.WordCount  hdfs:///tmp/words/ hdfs:///tmp/wc/run-$RANDOM/

