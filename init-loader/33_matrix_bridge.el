;;; 33_matrix_bridge.el --- 라운지 브릿지 자동 기동 (x600)  -*- lexical-binding: t; -*-

;; 왜 이 파일이 있는가 (2026-09-06, m1 발견을 x600 에서 재확인):
;;
;; elisp 릴레이는 지금까지 **손으로 띄운 타이머**로만 돌고 있었다. init 계열에
;; `matrix-bridge` 참조가 0건이었다(실측). 즉 emacs 가 재시작되면 릴레이가 아예
;; 안 뜬다. 파이썬 브릿지까지 내린 뒤에 그 일이 벌어지면 **라운지가 통째로 안
;; 들어오는데 에러도 안 난다** — 끊긴 사슬과 조용한 정상이 화면에서 구별되지
;; 않는 그 모양이다. 그래서 파이썬을 내리기 전에 이 파일이 먼저 있어야 한다.
;;
;; ⚠ 경로에 대하여: 정본은 `origin/main:matrix-bridge.el` 이지만, 이 기계의
;; cc-butler 체크아웃은 지금 피처 브랜치(`fix/steward-template-prod-data-boundary`)
;; 에 있고 **그 브랜치에는 이 파일이 아예 없다**(`git ls-files` 0건). 그래서
;; 레포 경로를 가리키면 아무것도 로드되지 않는다. 아래 서비스 디렉터리 사본은
;; `origin/main` 판과 **바이트 동일**하다 (2026-09-06 PR #175 머지 직후 대조,
;; sha256 c378985e085fe80c388e3bf04f4681acf4f4d7833ca00b1ed464a1284e72c089).
;; 레포 경로로의 정본화는 그 체크아웃이 main 에 올라온 뒤에 한다.

(defconst my/matrix-bridge-file
  (expand-file-name "~/services/matrix-bridge/matrix-bridge.el"))

;; ⚠ PR #175(2026-09-06 머지) 이후 정본의 `matrix-bridge-self-user-id` 기본값은
;; **nil** 이고, nil 이면 `matrix-bridge-start` 가 아예 거부한다. 즉 이 값이
;; 없으면 릴레이가 안 뜬다 — 조용히 죽는 대신 크게 죽는다. 아래 `boot` 는
;; 반드시 `matrix-bridge-start` **전에** 이 값을 넣는다.
;;
;; ⚠ 이 값 자체는 여기 박아 두지 않는다 (2026-09-07, steward 배차): 이 파일이
;; 사는 `toracle/.emacs.d` 는 PUBLIC 저장소다. 함대 id 를 여기 하드코딩하면
;; #175 가 없앤 안티패턴을 파일 하나 옆으로 옮기는 것뿐이고, 이 머신을
;; 복제하거나 다른 함대가 이 init-loader 를 가져가는 순간 #175 이전으로
;; 되돌아간다 — 그 함대 메시지만 조용히 사라지는 그 버그로. 그래서 값은
;; `my/matrix-bridge-identity-file' (공개 저장소 밖) 에 두고, 여기서는
;; 그 파일을 로드만 한다 — 없으면 #175 의 정신 그대로 **크게** 실패한다.
(defconst my/matrix-bridge-identity-file
  (expand-file-name "~/.config/cc-butler/fleet-identity.el")
  "이 머신의 함대 identity — `~/.emacs.d' 바깥, 공개 저장소 밖에 둔다.")

(defun my/matrix-bridge-boot ()
  "브릿지를 로드하고 기동한다.  실패는 **크게** 알린다 — 조용한 실패가 이 파일의 적이다."
  (cond
   ((not (file-readable-p my/matrix-bridge-file))
    (display-warning 'matrix-bridge
                     (format "브릿지 파일 없음: %s — 라운지 수신이 죽습니다"
                             my/matrix-bridge-file)
                     :emergency))
   ((not (file-readable-p my/matrix-bridge-identity-file))
    (display-warning 'matrix-bridge
                     (format "함대 identity 파일 없음: %s — 라운지 수신이 죽습니다 (PR #175: 기본값 nil 은 기동을 거부합니다)"
                             my/matrix-bridge-identity-file)
                     :emergency))
   (t
    (condition-case err
        (progn
          (load my/matrix-bridge-identity-file nil t)
          (unless (and (boundp 'my/matrix-bridge-self-user-id)
                      my/matrix-bridge-self-user-id)
            (error "%s 를 로드했지만 my/matrix-bridge-self-user-id 를 설정하지 않음"
                   my/matrix-bridge-identity-file))
          (load my/matrix-bridge-file nil t)
          (setq matrix-bridge-self-user-id my/matrix-bridge-self-user-id)
          ;; 이미 타이머가 돌고 있으면 두 번 띄우지 않는다 — 중복 배달이 된다
          ;; (m1 이 09-06 에 파이썬과 elisp 동시 가동으로 실제로 겪은 것).
          (if (and (boundp 'matrix-bridge--timer) (timerp matrix-bridge--timer))
              (message "matrix-bridge: 이미 기동됨 — 건너뜀")
            (matrix-bridge-start)
            (message "matrix-bridge: 기동 완료 (self=%s)" matrix-bridge-self-user-id)))
      (error
       (display-warning 'matrix-bridge
                        (format "브릿지 기동 실패: %S — 라운지 수신이 죽습니다" err)
                        :emergency))))))

(add-hook 'emacs-startup-hook #'my/matrix-bridge-boot)

;;; 33_matrix_bridge.el ends here
