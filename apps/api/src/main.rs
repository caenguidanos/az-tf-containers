use axum::{routing::get, Router};
use dotenv::dotenv;
use sqlx::mysql::MySqlPoolOptions;
use tokio::signal;
use tower_http::cors::CorsLayer;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let settings = Settings::new();
    tracing::debug!("settings initialized");

    let _ = MySqlPoolOptions::new()
        .max_connections(5)
        .connect(
            format!(
                "mysql://{}:{}@{}:3306/{}",
                settings.db_user, settings.db_pass, settings.db_host, settings.db_name
            )
            .as_str(),
        )
        .await
        .unwrap();
    tracing::debug!("connected to database");

    let app =
        Router::new()
            .route("/healthz", get(|| async { "OK" }))
            .route(
                "/",
                get(|| async move {
                    format!("Hello, from {} resource group!", settings.az_resource_group)
                }),
            )
            .layer(CorsLayer::very_permissive());

    tracing::debug!("router initialized");
    axum::Server::bind(&"0.0.0.0:8080".parse().unwrap())
        .serve(app.into_make_service())
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}

#[derive(Clone)]
pub struct Settings {
    pub db_host: String,
    pub db_user: String,
    pub db_pass: String,
    pub db_name: String,

    pub az_resource_group: String,
}

impl Settings {
    pub fn new() -> Self {
        Self {
            db_host: std::env::var("DATABASE_HOST").expect("DATABASE_HOST"),
            db_user: std::env::var("DATABASE_USER").expect("DATABASE_USER"),
            db_pass: std::env::var("DATABASE_PASS").expect("DATABASE_PASS"),
            db_name: std::env::var("DATABASE_NAME").expect("DATABASE_NAME"),

            az_resource_group: std::env::var("AZURE_RESOURCE_GROUP_NAME")
                .expect("AZURE_RESOURCE_GROUP_NAME"),
        }
    }
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    println!("signal received, starting graceful shutdown");
}
