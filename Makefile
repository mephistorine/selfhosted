# Пингует все сервера из инвентори файла
ping:
	ansible all -i ./inventory.ini --vault-password-file .vaultpass -u root -m 'ping'
deploy:
	ansible-playbook -i inventory.ini --vault-password-file .vaultpass deploy.playbook.yml
serverList:
	ansible-inventory -i inventory.ini --vault-password-file .vaultpass --list
serverGraph:
	ansible-inventory -i inventory.ini --vault-password-file .vaultpass --graph
installDeps:
	ansible-galaxy install -r requirements.yml
