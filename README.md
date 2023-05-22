# İşletim Sistemleri Dersi Ödevi

## Tanım

Gazi Üniversitesi İşletim Sistemleri ödevi için Ubuntu işletim sistemine gerekli kurumları içermektedir.

### İçerik

- Postgresql (Zorunlu Stack)
- Nginx (Zorunlu Stack)
- Python (Zorunlu Stack)
- LDAP (Zorunlu Yüklenecek)
- SSH (Zorunlu Yüklenecek)
- Shell Script (Seçimli Yüklenecek)
- Syslog-ng (Seçimli Yüklenecek)
- Nagios (Seçimli Yüklenecek)

### Test edilmesi

- [*http://localhost/*](http://localhost/) adresi üzerinden Nginx reverse proxy ile Flask uygulamasına ulaşılabilir. Tüm ekip
arkadaşlarının ismi ve ismiyle aynı şifresi ile giriş yapılabilir.
- Girişler LDAP üzerinden kontrol edilmektedir.
- Veritabanı için [**jdbc:postgresql://localhost:5432/postgres**](jdbc:postgresql://localhost:5432/postgres) üzerinden PostgreSQL
veritabanına kullanıcı adı admin, şifre admin olacak şekilde ulaşılabilir. Tüm kullanıcı girişleri *LOG* tablosunda loglanmaktadır.
- Nagios'a [*http://localhost:8080/nagios/*](http://localhost:8080/nagios/) adresi üzerinden kullanıcı adı nagiosadmin şifre password
ile ulaşılanilir.
- Sunucuya ssh bağlantısı için `ssh kaan@localhost` kodu ile khg şifresi ile ulaşılabilir.
- Syslog-ng ile yakalanan sistem loglarına ulaşmak içn `cat /var/log/messages` komutu ile ulaşılabilir.

### Çalıştırılması

```bash
git clone https://github.com/KaanHanGunay/GaziIsletimSistemleriOdev
cd GaziIsletimSistemleriOdev
sudo chmod +x install.sh
sudo ./install.sh
```
