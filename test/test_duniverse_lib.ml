let () =
  Alcotest.run "Duniverse"
    [
      Test_uri_utils.suite;
      Test_opam.suite;
      Test_duniverse.suite;
      Test_dune_file.suite;
      Test_git.suite;
      Test_parallel.suite;
      Test_opam_value.suite;
    ]
