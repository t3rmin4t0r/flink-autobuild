# flink-autobuild

An easy way to build [Flink-on-Tez](https://ci.apache.org/projects/flink/flink-docs-master/setup/flink_on_tez.html#setup) for dev purposes

    $ make dist install
    $ ./dist/flink/flink-tez org.apache.flink.tez.examples.WordCount  hdfs:///tmp/words/ hdfs:///tmp/wc/run-$RANDOM/

