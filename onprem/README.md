# onprem/ — 온프레미스 랩 (Vagrant + VirtualBox)

하이브리드 공격 경로 탐색 시스템의 "온프레미스" 절반. WordPress 서버에 저장된 IAM 액세스 키가
AWS(S3)로 넘어가는 경계 이동을 재현한다 (시나리오 S1/S3의 진입점).

## 구성

| VM | 역할 | IP | 노출 |
| --- | --- | --- | --- |
| `hap-onprem-web` | Apache+PHP+WordPress, AWS CLI, 백업/로그 에이전트 | `192.168.0.10` | host:8080 → 80 |
| `hap-onprem-db` | MySQL 8.0 (WordPress 백엔드), 로그 에이전트 | `192.168.0.30` | 없음 (web에서만 접근) |

두 VM은 private network `192.168.0.0/24`로 통신한다 (web → db:3306).

```
onprem/
├─ Vagrantfile              # VM 2대(web·db) + network + provision
├─ provision/
│  ├─ web.sh                # Apache/PHP/WordPress/AWS CLI/로그·백업 cron
│  └─ db.sh                 # MySQL 8.0 + 로그 cron
├─ scripts/
│  ├─ backup-to-s3.sh       # WordPress 데이터 → hap-customer-data-s3
│  └─ ship-logs-to-s3.sh    # 로그 → hap-soc-log-s3/onprem/...
└─ README.md
```

## 실행 방법 (수동, Windows + VirtualBox 기준)

### 0. 사전 준비
- VirtualBox, Vagrant 설치.
- VirtualBox가 PATH에 없어도 무방 — `VBOX_MSI_INSTALL_PATH` 환경변수(설치 시 자동 등록)만
  있으면 Vagrant가 인식한다.

### 1. VM 기동 (db 먼저 → web)
```powershell
cd onprem

# IAM 키가 확정되면 아래 환경변수로 주입 (미설정 시 placeholder 사용)
$env:HAP_WEB_AWS_ACCESS_KEY_ID = "..."
$env:HAP_WEB_AWS_SECRET_ACCESS_KEY = "..."
$env:HAP_DB_AWS_ACCESS_KEY_ID = "..."
$env:HAP_DB_AWS_SECRET_ACCESS_KEY = "..."

vagrant up hap-onprem-db
vagrant up hap-onprem-web
```
최초 실행은 `ubuntu/jammy64` 박스 다운로드(수백MB) + 패키지 설치로 10~20분 정도 걸릴 수 있다.

### 2. 확인
```powershell
# private network로 서비스 응답 확인
Test-NetConnection -ComputerName 192.168.0.30 -Port 3306   # db: MySQL
Test-NetConnection -ComputerName 192.168.0.10 -Port 80      # web: Apache
```
브라우저에서 `http://localhost:8080` 접속 → WordPress 설치 마법사가 뜨면 정상.
(DB 연결 에러가 뜨면 3번 문제 상황 참고.)

### 3. 자주 겪는 문제와 해결
| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `vagrant up` 중 `File.exists?` NoMethodError로 크래시 후 VM이 destroy됨 | 로컬에 설치된 `vagrant-vbguest` 플러그인이 최신 Vagrant의 Ruby와 호환 안 됨 | Vagrantfile에 이미 `config.vbguest.auto_update = false` 반영됨. 그래도 재발하면 `vagrant plugin uninstall vagrant-vbguest` |
| `cp: cannot stat '/vagrant/scripts/...'` | Guest Additions 버전(박스 내장 6.0.0)과 VirtualBox 버전 불일치로 공유폴더(`/vagrant`)가 마운트 안 됨 | Vagrantfile이 `file` provisioner(SCP)로 스크립트를 `/tmp`에 전달하도록 이미 수정됨. 재발 시 `vagrant provision <name>`으로 재적용 |
| `192.168.0.30`/`192.168.0.10` ping·포트 응답 없음 (VM은 `running`인데) | Ubuntu 22.04(netplan/cloud-init) 이미지에서 Vagrant의 private_network 설정이 재부팅 후 유지되지 않음 | `provision/db.sh`, `provision/web.sh`에 netplan 고정 설정 + cloud-init 네트워크 재설정 비활성화가 이미 반영됨. 그래도 안 되면 `vagrant reload <name>` 한 번, 그래도 안 되면 `vagrant halt <name>` → `vagrant up <name>` 으로 완전 재부팅 |
| `vagrant provision`이 "Guest-specific operations were attempted on a machine that is not ready" 로 실패 | 이전 세션의 SSH 키/연결 상태가 꼬임 | `vagrant halt <name>` → `vagrant up <name>` 으로 새 SSH 키 교환을 유도 |
| `vagrant halt`가 "another process is already executing an action" 로 실패 | 이전 vagrant 프로세스가 비정상 종료되며 lock이 안 풀림(실제 ruby/vagrant 프로세스는 이미 종료된 경우가 대부분) | 잠시 후 재시도. 계속되면 작업관리자에서 `ruby`/`vagrant` 프로세스 확인 후 종료 |

### 4. 종료 / 재개
```powershell
vagrant halt        # 두 VM 모두 정지 (디스크 상태 보존, 재프로비저닝 불필요)
vagrant up          # 다음에 그대로 재개
vagrant destroy     # 완전히 지우고 처음부터 다시 만들 때만 사용
```

## 로그/백업 흐름

- collector는 AWS private 이라 온프렘에서 직접 전송 불가 → **IAM 키로 S3에 직접 저장**하고
  SOC collector가 S3에서 읽어 정제한다.
- 전송 방식은 **AWS CLI + cron** (`aws s3 cp`), Filebeat는 S3 직접 출력을 지원하지 않아 채택하지 않음.

| 출처 | 저장 위치(S3 prefix) |
| --- | --- |
| WordPress 웹/앱 (Apache access/error) | `hap-soc-log-s3/onprem/wordpress/` |
| MySQL (general/slow query) | `hap-soc-log-s3/onprem/mysql/` |
| OS (syslog, auth.log, auditd) | `hap-soc-log-s3/onprem/os/` |
| 백업 실행 로그 | `hap-soc-log-s3/onprem/backup/` |
| WordPress 데이터(파일+DB 덤프) | `hap-customer-data-s3` |

백업 로그(성공/실패·버킷·실행 계정)는 CloudTrail의 S3 PutObject 기록과 대조해
"정상 백업 vs 키 탈취 악용"을 판별하는 데 쓰인다 (시나리오 S3 탐지 핵심).

## 주의사항

1. **IAM 키 실값을 이 폴더 어디에도 하드코딩하지 않는다.** Vagrantfile은 항상 환경변수를
   읽어 placeholder(`REPLACE_WITH_IAM_ACCESS_KEY` 등)로 대체한다. 실값은 별도 키 설계 확정 후 주입.
2. **의도적 취약 앱(플러그인 CVE 등)을 심지 않는다.** WordPress는 표준 설치이며, 공격 표면은
   앱 취약점이 아니라 **web 서버 로컬에 저장된 IAM 키**뿐이다.
3. AWS 인프라(S3 버킷, collector 등)는 Terraform이 관리 — 이 폴더는 접근만 한다.
