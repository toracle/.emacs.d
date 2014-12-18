사용 방법

## Cask 설치

아래 명령으로 Cask를 설치한다.

``$ curl -fsSkL https://raw.github.com/cask/cask/master/go | python``

본 저장소를 clone받아 ~/.emacs.d/ 디렉토리로 삼는다. 그리고 아래 명령을 실행한다.

``$ cask install``

이제 Emacs를 실행한다.


## 외부 라이브러리 설치 (Pymacs 등)

Emacs 라이브러리 이외에 외부 라이브러리를 설치해줘야 하는 녀석들이 있다.

 * elpy
 * Pymacs
 * ropemacs


Elpy에 필요한 라이브러리들을 설치하기 위해서는 아래 명령을 수행한다.

```
pip install rope
pip install ropemode
pip install flake8
```

