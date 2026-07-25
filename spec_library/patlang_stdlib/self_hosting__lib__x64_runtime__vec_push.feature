Feature: vec_new/vec_push/vec_get (x64 backend's own handle-based list, self_hosting/lib/x64_runtime.patlang)

  Scenario: Pushed items are retrievable by index in order
    Given a fresh handle from vec_new
    When 10, 20, 30 are pushed via vec_push
    Then vec_get(h,0)=10, vec_get(h,1)=20, vec_get(h,2)=30

