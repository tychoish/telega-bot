;;; test-telega-bot.el --- Tests for telega-bot -*- lexical-binding: t; -*-

(require 'ert)
(require 'telega-bot)
(require 'telega-bot-alert)

(ert-deftest telega-bot-test-create-and-registry ()
  "Test creating a bot and registering it in telega-bot-registry."
  (let ((telega-bot-registry nil))
    (let ((bot (make-telega-bot :name "TestBot" :token "token-123")))
      (should (equal (telega-bot-name bot) "TestBot"))
      (should (equal (telega-bot-token bot) "token-123"))
      (should (eq (telega-bot-get "TestBot") bot))
      (should (eq (telega-bot-get 'TestBot) bot))
      (telega-bot-unregister 'TestBot)
      (should-not (telega-bot-get "TestBot")))))

(ert-deftest telega-bot-test-extract-command ()
  "Test extracting command from incoming message text."
  (should (equal (telega-bot--extract-command "/start") "/start"))
  (should (equal (telega-bot--extract-command "/start@MyBot") "/start"))
  (should (equal (telega-bot--extract-command "/start@MyBot with arguments") "/start"))
  (should (equal (telega-bot--extract-command "/help   foo bar") "/help"))
  (should-not (telega-bot--extract-command "plain message without slash")))

(ert-deftest telega-bot-test-state-management ()
  "Test user FSM state tracking."
  (let ((bot (make-telega-bot :name "StateBot")))
    (should-not (telega-bot-get-state bot 100 200))
    (telega-bot-set-state bot 100 200 'awaiting-input :data '(:step 1))
    (let ((state (telega-bot-get-state bot 100 200)))
      (should (equal (car state) 'awaiting-input))
      (should (equal (plist-get (cdr state) :step) 1)))
    (telega-bot-clear-state bot 100 200)
    (should-not (telega-bot-get-state bot 100 200))))

(ert-deftest telega-bot-test-register-command-handler ()
  "Test registering and dispatching command handlers."
  (let ((bot (make-telega-bot :name "CmdBot"))
        (called nil))
    (telega-bot-register-handler test-cmd 'CmdBot
      :operation :command
      :pattern "/ping"
      (setq called t))
    (let ((handler (telega-bot--find-message-handler bot "/ping")))
      (should (functionp handler))
      (funcall handler)
      (should (eq called t)))))

(ert-deftest telega-bot-test-register-fuzzy-handler ()
  "Test regex/fuzzy matching handlers."
  (let ((bot (make-telega-bot :name "FuzzyBot"))
        (captured-text nil))
    (telega-bot-register-handler greet 'FuzzyBot
      :operation :fuzzymatch
      :pattern "^[Hh]ello"
      :args (&key text)
      (setq captured-text text))
    (let ((handler (telega-bot--find-message-handler bot "Hello there!")))
      (should (functionp handler))
      (funcall handler :text "Hello there!")
      (should (equal captured-text "Hello there!")))))

(ert-deftest telega-bot-test-alert-target-management ()
  "Test registering, retrieving, and unregistering alert targets."
  (let ((telega-bot-alert-targets nil))
    (telega-bot-alert-register-target
     :name "ops"
     :bot 'OpsBot
     :chat-id 12345
     :thread-id 678)
    (let ((target (telega-bot-alert-get-target "ops")))
      (should target)
      (should (eq (telega-bot-alert-target-bot target) 'OpsBot))
      (should (equal (telega-bot-alert-target-chat-id target) 12345))
      (should (equal (telega-bot-alert-target-thread-id target) 678)))
    (telega-bot-alert-unregister-target "ops")
    (should-not (telega-bot-alert-get-target "ops"))))

(ert-deftest telega-bot-test-alert-formatting ()
  "Test formatting alert messages."
  (let ((info '(:message "Server high load" :title "CPU Alert")))
    (should (equal (telega-bot-alert--format-message info)
                   "*CPU Alert*\nServer high load")))
  (let ((info '(:message "Plain message")))
    (should (equal (telega-bot-alert--format-message info)
                   "Plain message"))))

(provide 'test-telega-bot)
;;; test-telega-bot.el ends here
