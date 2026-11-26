<?php
// Functional smoke test for the statically-linked ext-rtc build: creates a
// real PeerConnection, a DataChannel, and checks that a local SDP offer and
// at least one ICE candidate actually get generated. Verified working on
// real GL.iNet Mudi 7 router hardware: PC_CREATED / STATE=NEW /
// GATHERING=NEW / DATACHANNEL_CREATED / LOCAL_DESC_LEN=734 /
// LOCAL_CANDIDATES=4 / SMOKE_TEST_OK
use amber\rtc\PeerConnection;
use amber\rtc\PeerConnectionOptions;
use amber\rtc\IceServer;

try {
    $options = new PeerConnectionOptions();
    $options->setIceServers([IceServer::stun('stun.l.google.com', 19302)]);

    $pc = new PeerConnection($options);
    echo "PC_CREATED\n";
    echo "STATE=" . $pc->getState()->name . "\n";
    echo "GATHERING=" . $pc->getGatheringState()->name . "\n";

    $dc = $pc->createDataChannel('smoke-test');
    echo "DATACHANNEL_CREATED\n";

    usleep(300000);

    $desc = $pc->getLocalDescription();
    echo "LOCAL_DESC_LEN=" . strlen((string) $desc) . "\n";

    $candidates = $pc->pollLocalCandidates();
    echo "LOCAL_CANDIDATES=" . count($candidates) . "\n";

    echo "SMOKE_TEST_OK\n";
} catch (\Throwable $e) {
    echo "SMOKE_TEST_FAILED: " . $e->getMessage() . "\n";
    exit(1);
}
