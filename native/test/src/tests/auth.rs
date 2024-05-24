use acter::api::{
    guest_client, login_new_client, login_new_client_under_config, login_with_token_under_config,
    make_client_config, request_registration_token_via_email,
};
use anyhow::Result;
use tempfile::TempDir;
use tracing::{info, warn};
use uuid::Uuid;

use crate::utils::{default_user_password, login_test_user, random_user_with_random_space};

#[tokio::test]
async fn guest_can_login() -> Result<()> {
    let _ = env_logger::try_init();
    let should_test = option_env!("GUEST_ACCESS").unwrap_or("false");
    if should_test == "1" || should_test == "true" {
        let homeserver_name = option_env!("DEFAULT_HOMESERVER_NAME")
            .unwrap_or("localhost")
            .to_string();
        let homeserver_url = option_env!("DEFAULT_HOMESERVER_URL")
            .unwrap_or("http://localhost:8118")
            .to_string();

        let tmp_dir = TempDir::new()?;
        let _client = guest_client(
            tmp_dir.path().to_string_lossy().to_string(),
            tmp_dir.path().to_string_lossy().to_string(),
            homeserver_name,
            homeserver_url,
            Some("GUEST_DEV".to_string()),
        )
        .await?;
    } else {
        warn!("Skipping guest test. To run set env var GUEST_ACCESS=1");
    }
    Ok(())
}

#[tokio::test]
async fn sisko_can_login() -> Result<()> {
    let _ = env_logger::try_init();
    let homeserver_name = option_env!("DEFAULT_HOMESERVER_NAME")
        .unwrap_or("localhost")
        .to_string();
    let homeserver_url = option_env!("DEFAULT_HOMESERVER_URL")
        .unwrap_or("http://localhost:8118")
        .to_string();

    let tmp_dir = TempDir::new()?;
    let _client = login_new_client(
        tmp_dir.path().to_string_lossy().to_string(),
        tmp_dir.path().to_string_lossy().to_string(),
        "@sisko".to_string(),
        default_user_password("sisko"),
        homeserver_name,
        homeserver_url,
        Some("SISKO_DEV".to_string()),
    )
    .await?;
    Ok(())
}

#[tokio::test]
async fn kyra_can_login() -> Result<()> {
    let _ = env_logger::try_init();
    let tmp_dir = TempDir::new()?;
    let homeserver_name = option_env!("DEFAULT_HOMESERVER_NAME")
        .unwrap_or("localhost")
        .to_string();
    let homeserver_url = option_env!("DEFAULT_HOMESERVER_URL")
        .unwrap_or("http://localhost:8118")
        .to_string();

    let _client = login_new_client(
        tmp_dir.path().to_string_lossy().to_string(),
        tmp_dir.path().to_string_lossy().to_string(),
        "@kyra".to_string(),
        default_user_password("kyra"),
        homeserver_name,
        homeserver_url,
        Some("KYRA_DEV".to_string()),
    )
    .await?;
    Ok(())
}

#[tokio::test]
async fn kyra_can_restore() -> Result<()> {
    let _ = env_logger::try_init();
    let homeserver_name = option_env!("DEFAULT_HOMESERVER_NAME")
        .unwrap_or("localhost")
        .to_string();
    let homeserver_url = option_env!("DEFAULT_HOMESERVER_URL")
        .unwrap_or("http://localhost:8118")
        .to_string();
    let base_dir = TempDir::new()?;
    let media_dir = TempDir::new()?;
    let (config, user_id) = make_client_config(
        base_dir.path().to_string_lossy().to_string(),
        "@kyra",
        media_dir.path().to_string_lossy().to_string(),
        None,
        &homeserver_name,
        &homeserver_url,
        true,
    )
    .await?;

    let (token, user_id) = {
        let client = login_new_client_under_config(
            config.clone(),
            user_id,
            default_user_password("kyra"),
            None,
            Some("KYRA_DEV".to_string()),
        )
        .await?;
        let token = client.restore_token().await?;
        let user_id = client
            .user_id()
            .expect("username missing after login. weird");
        (serde_json::from_str(&token)?, user_id)
    };

    let client = login_with_token_under_config(token, config).await?;
    let uid = client
        .user_id()
        .expect("Login by token seems to be not working");
    assert_eq!(uid, user_id);
    Ok(())
}

#[tokio::test]
async fn kyra_can_restore_with_db_passphrase() -> Result<()> {
    let _ = env_logger::try_init();
    let homeserver_name = option_env!("DEFAULT_HOMESERVER_NAME")
        .unwrap_or("localhost")
        .to_string();
    let homeserver_url = option_env!("DEFAULT_HOMESERVER_URL")
        .unwrap_or("http://localhost:8118")
        .to_string();
    let base_dir = TempDir::new()?;
    let media_dir = TempDir::new()?;
    let db_passphrase = Uuid::new_v4().to_string();
    let (config, user_id) = make_client_config(
        base_dir.path().to_string_lossy().to_string(),
        "@kyra",
        media_dir.path().to_string_lossy().to_string(),
        Some(db_passphrase.clone()),
        &homeserver_name,
        &homeserver_url,
        true,
    )
    .await?;

    let (token, user_id) = {
        let client = login_new_client_under_config(
            config.clone(),
            user_id,
            default_user_password("kyra"),
            Some(db_passphrase),
            Some("KYRA_DEV".to_string()),
        )
        .await?;
        let token = client.restore_token().await?;
        let user_id = client
            .user_id()
            .expect("username missing after login. weird");
        (serde_json::from_str(&token)?, user_id)
    };

    let client = login_with_token_under_config(token, config).await?;
    let uid = client
        .user_id()
        .expect("Login by token with db_passphrase seems to be not working");
    assert_eq!(uid, user_id);
    Ok(())
}

#[tokio::test]
async fn can_deactivate_user() -> Result<()> {
    let _ = env_logger::try_init();
    let username = {
        let (client, _space_id) = random_user_with_random_space("deactivate_me").await?;
        // password in tests can be figured out from the username
        let username = client.user_id().expect("we just logged in");
        let password = default_user_password(username.localpart());
        print!("with password: {password}");
        assert!(client.deactivate(password).await?, "deactivation failed");
        username
    };

    // now trying to login or should fail as the user has been deactivated
    // and registration is blocked because it is in use.

    assert!(
        login_test_user(username.localpart().to_string())
            .await
            .is_err(),
        "Was still able to login or register that username"
    );
    Ok(())
}

#[tokio::test]
async fn user_changes_password() -> Result<()> {
    let _ = env_logger::try_init();

    let (mut client, _) = random_user_with_random_space("change_password").await?;
    let user_id = client.user_id().expect("we just logged in");
    let password = default_user_password(user_id.localpart());
    let new_password = format!("new_{:?}", password.as_str());

    let result = client
        .clone()
        .change_password(password.clone(), new_password.clone())
        .await?;
    assert!(result, "Couldn't change password successfully");

    let result = client.logout().await?;
    assert!(result, "Couldn't logout successfully");

    let base_dir = TempDir::new()?;
    let media_dir = TempDir::new()?;
    let (config, uid) = make_client_config(
        base_dir.path().to_string_lossy().to_string(),
        user_id.localpart(),
        media_dir.path().to_string_lossy().to_string(),
        None,
        option_env!("DEFAULT_HOMESERVER_NAME").unwrap_or("localhost"),
        option_env!("DEFAULT_HOMESERVER_URL").unwrap_or("http://localhost:8118"),
        true,
    )
    .await?;

    let old_pswd_res =
        login_new_client_under_config(config.clone(), uid.clone(), password, None, None).await;
    assert!(old_pswd_res.is_err(), "Can't login with old password");

    let new_pswd_res = login_new_client_under_config(config, uid, new_password, None, None).await;
    assert!(
        new_pswd_res.is_ok(),
        "Should be able to login with new password"
    );
    Ok(())
}

#[tokio::test]
async fn can_request_registration_token_via_email() -> Result<()> {
    let _ = env_logger::try_init();

    let base_dir = TempDir::new()?;
    let media_dir = TempDir::new()?;
    let prefix = "reset_password".to_owned();
    let uuid = Uuid::new_v4().to_string();
    let email = "test2@localhost".to_owned();

    let resp = request_registration_token_via_email(
        base_dir.path().to_string_lossy().to_string(),
        media_dir.path().to_string_lossy().to_string(),
        format!("it-{prefix}-{uuid}"),
        option_env!("DEFAULT_HOMESERVER_NAME")
            .unwrap_or("localhost")
            .to_owned(),
        option_env!("DEFAULT_HOMESERVER_URL")
            .unwrap_or("http://localhost:8118")
            .to_owned(),
        email,
    )
    .await?;

    info!("registration token via email - sid: {}", resp.sid());
    info!(
        "registration token via email - submit_url: {:?}",
        resp.submit_url().text(),
    );

    Ok(())
}
