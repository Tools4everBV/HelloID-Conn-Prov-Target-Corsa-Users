# HelloID-Conn-Prov-Target-Corsa-Users

> [!IMPORTANT]  
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

## Table of contents

- [HelloID-Conn-Prov-Target-Corsa-Users](#helloid-conn-prov-target-corsa-users)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Connection settings](#connection-settings)
  - [Correlation configuration](#correlation-configuration)
    - [Available Lifecycle Actions](#available-lifecycle-actions)
    - [CSV structure](#csv-structure)
  - [Remarks](#remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Corsa-Users_ is a target connector that writes person/user attribute values to tab delimited CSV file. This file will be imported by Corsa to create/update user accounts.

## Getting started

### Prerequisites

- HelloID Agent running On-Premises
- Write access to a shared location for storing the blacklist CSV file
- **Concurrent actions should be set to 1** to avoid file locking or accidental overwrites


### Connection settings

The following settings are required to connect to the CSV file.

| Setting                | Description                                                                                                                               | Mandatory |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| CSV File Path          | Full path to the CSV file                                                                                                                 | Yes       |
| Encoding               | Encoding used (e.g. `utf-8`, `ascii`)                                                                                                     | Yes       |

## Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _{connectorName}_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value        |
    | ------------------------- | ------------ |
    | Enable correlation        | `True`       |
    | Person correlation field  | `ExternalId`           |
    | Account correlation field | `Code_personeel` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Available Lifecycle Actions

The following lifecycle actions are available in this connector:

| Action                         | Description                                                                                                                                                                                                                                                                                                                                                                                                 | Comment                                                                                                   |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `create.ps1`                   | Adds account data to the CSV. A new row is added if the employeeid is not found to be present. | Uses account data from another system like AD or Entra ID.                                                |
| `update.ps1`                   | Follows the same logic as `create.ps1`.                                                                                                                                                                                                                                                                                         |                                                                                                           |
| `fieldMapping.json`            | Defines mappings between person fields and target system person account fields.                                                                                                                                                                                                                                                                                                                             |                                                                                                           |


### CSV structure

The fieldnames in the mapping correspond with the headers in de csv file

## Remarks

- This connector uses a local CSV file as storage and source of truth.
- As the CSV requires the columns to be at a specific position, the ordering of the fields is added to the create and update script. When a new field is added, these scripts should be updated as well
- Corsa starts importing data at line 3 of the csv file. Headers are not imported by Corsa.

## Getting help

> [!TIP]  
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]  
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/