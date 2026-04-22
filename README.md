------------------------------------------------------------------------------------------------------
ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------
L’idée en 30 secondes : **Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé**.  
Cet atelier propose de concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, des actions d’infrastructure sur des **instances EC2**, le tout dans un **environnement AWS simulé avec LocalStack** et exécuté dans **GitHub Codespaces**. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.Cet atelier propose de concevoir une architecture API-driven dans laquelle une requête HTTP déclenche, via API Gateway et une fonction Lambda, des actions d’infrastructure sur des instances EC2, le tout dans un environnement AWS simulé avec LocalStack et exécuté dans GitHub Codespaces. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.
  
-------------------------------------------------------------------------------------------------------
Séquence 1 : Codespace de Github
-------------------------------------------------------------------------------------------------------
Objectif : Création d'un Codespace Github  
Difficulté : Très facile (~5 minutes)
-------------------------------------------------------------------------------------------------------
RDV sur Codespace de Github : <a href="https://github.com/features/codespaces" target="_blank">Codespace</a> **(click droit ouvrir dans un nouvel onglet)** puis créer un nouveau Codespace qui sera connecté à votre Repository API-Driven.
  
---------------------------------------------------
Séquence 2 : Création de l'environnement AWS (LocalStack)
---------------------------------------------------
Objectif : Créer l'environnement AWS simulé avec LocalStack  
Difficulté : Simple (~5 minutes)
---------------------------------------------------

Dans le terminal du Codespace copier/coller les codes ci-dessous etape par étape :  

**Installation de l'émulateur LocalStack**  
```
sudo -i mkdir rep_localstack
```
```
sudo -i python3 -m venv ./rep_localstack
```
```
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0
```
```
localstack start -d
```
**vérification des services disponibles**  
```
localstack status services
```
**Réccupération de l'API AWS Localstack** 
Votre environnement AWS (LocalStack) est prêt. Pour obtenir votre AWS_ENDPOINT cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **4566** (Visibilité du port).
Réccupérer l'URL de ce port dans votre navigateur qui sera votre ENDPOINT AWS (c'est à dire votre environnement AWS).
Conservez bien cette URL car vous en aurez besoin par la suite.  

Pour information : IL n'y a rien dans votre navigateur et c'est normal car il s'agit d'une API AWS (Pas un développement Web type UX).

ANYA :

LocalStack simule l'environnement AWS en local. On le lance via Docker :

```bash
docker run -d \
  --name localstack-main \
  -p 4566:4566 \
  -e SERVICES=ec2,lambda,apigateway,iam \
  -e DEFAULT_REGION=us-east-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  localstack/localstack:3.8.0

sleep 30
```

> ⚠️ Le volume `/var/run/docker.sock` est indispensable pour que Lambda puisse s'exécuter dans un conteneur Docker.

Configurer les credentials AWS (factices) :

```bash
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set region us-east-1
aws configure set output json
```

Vérifier que les services tournent :

```bash
awslocal ec2 describe-regions --output table
```

---

---------------------------------------------------
Séquence 3 : Exercice
---------------------------------------------------
Objectif : Piloter une instance EC2 via API Gateway
Difficulté : Moyen/Difficile (~2h)
---------------------------------------------------  
Votre mission (si vous l'acceptez) : Concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, lancera ou stopera une **instance EC2** déposée dans **environnement AWS simulé avec LocalStack** et qui sera exécuté dans **GitHub Codespaces**. [Option] Remplacez l'instance EC2 par l'arrêt ou le lancement d'un Docker.  

**Architecture cible :** Ci-dessous, l'architecture cible souhaitée.   
  
![Screenshot Actions](API_Driven.png)   
  
---------------------------------------------------  
## Processus de travail (résumé)

1. Installation de l'environnement Localstack (Séquence 2)
2. Création de l'instance EC2
3. Création des API (+ fonction Lambda)
4. Ouverture des ports et vérification du fonctionnement

ANYA :

### Option 1 — Automatique avec le Makefile (recommandé)

```bash
make deploy
```

Cette commande effectue automatiquement toutes les étapes ci-dessous.

### Option 2 — Manuel étape par étape

#### Étape 1 — Créer l'instance EC2

```bash
export INSTANCE_ID=$(awslocal ec2 run-instances \
  --image-id ami-ff0fea8310f3 \
  --instance-type t2.micro \
  --count 1 \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Instance ID : $INSTANCE_ID"
```

#### Étape 2 — Créer la fonction Lambda

```bash
awslocal iam create-role \
  --role-name lambda-role \
  --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

zip function.zip lambda_function.py

awslocal lambda create-function \
  --function-name ec2-controller \
  --runtime python3.11 \
  --handler lambda_function.lambda_handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://function.zip \
  --environment Variables={INSTANCE_ID=$INSTANCE_ID} \
  --timeout 30

sleep 15
```

#### Étape 3 — Créer l'API Gateway

```bash
export API_ID=$(awslocal apigateway create-rest-api \
  --name "EC2-Controller-API" \
  --query "id" --output text)

export ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id $API_ID \
  --query "items[0].id" --output text)

export RESOURCE_ID=$(awslocal apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part ec2 \
  --query "id" --output text)

awslocal apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE

awslocal apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:ec2-controller/invocations

awslocal apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod
```

---

---------------------------------------------------
Séquence 4 : Documentation  
Difficulté : Facile (~30 minutes)
---------------------------------------------------
**Complétez et documentez ce fichier README.md** pour nous expliquer comment utiliser votre solution.  
Faites preuve de pédagogie et soyez clair dans vos expliquations et processus de travail.  
   
---------------------------------------------------
Evaluation
---------------------------------------------------
Cet atelier, **noté sur 20 points**, est évalué sur la base du barème suivant :  
- Repository exécutable sans erreur majeure (4 points)
- Fonctionnement conforme au scénario annoncé (4 points)
- Degré d'automatisation du projet (utilisation de Makefile ? script ? ...) (4 points)
- Qualité du Readme (lisibilité, erreur, ...) (4 points)
- Processus travail (quantité de commits, cohérence globale, interventions externes, ...) (4 points) 


ANYA :

Récupérer l'API ID :

```bash
export API_ID=$(awslocal apigateway get-rest-apis \
  --query "items[0].id" --output text)
```

Tester les 3 actions disponibles :

```bash
# Vérifier l'état de l'instance
curl "http://localhost:4566/restapis/$API_ID/prod/_user_request_/ec2?action=status"

# Stopper l'instance
curl "http://localhost:4566/restapis/$API_ID/prod/_user_request_/ec2?action=stop"

# Démarrer l'instance
curl "http://localhost:4566/restapis/$API_ID/prod/_user_request_/ec2?action=start"
```

Résultats attendus :

```json
{"message": "Instance i-xxx - Etat : running"}
{"message": "Instance i-xxx stoppee"}
{"message": "Instance i-xxx demarree"}
```

---

## Utilisation du Makefile

| Commande | Description |
|----------|-------------|
| `make deploy` | Lance LocalStack + déploie toute l'infrastructure |
| `make status` | Vérifie l'état de l'instance EC2 |
| `make stop` | Stoppe l'instance EC2 |
| `make start` | Démarre l'instance EC2 |

---
## Flux de travail

1. LocalStack démarre dans Docker avec accès au socket Docker
2. Une instance EC2 simulée est créée
3. Une Lambda Python reçoit les requêtes HTTP via API Gateway
4. La Lambda appelle l'API EC2 de LocalStack pour démarrer/stopper l'instance
5. La réponse est retournée au client HTTP

---

## Problèmes rencontrés et solutions

| Problème | Solution |
|----------|----------|
| `localstack` binaire introuvable | Utiliser Docker directement |
| Lambda en état `Failed` | Ajouter `-v /var/run/docker.sock:/var/run/docker.sock` au lancement Docker |
| `InvalidInstanceID.NotFound` | Mettre à jour la variable INSTANCE_ID avec `update-function-configuration` |
| 403 sur le navigateur | Normal — tester avec `curl` depuis le terminal |
