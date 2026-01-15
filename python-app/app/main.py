"""Main application module for the Python microservice."""

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.config import settings

# Initialize FastAPI application
app = FastAPI(
    title="Python Microservice",
    description="A simple greeting microservice",
    version="1.0.0",
)


@app.get("/", response_class=JSONResponse)
async def root():
    """
    Root endpoint that returns a generic greeting.
    
    Returns:
        JSONResponse: A greeting message with the name from NOMBRE environment variable
    """
    nombre = settings.get_nombre()
    return JSONResponse(
        content={
            "message": f"¡Hola, {nombre}! Bienvenido al microservicio.",
            "status": "success"
        }
    )


@app.get("/health", response_class=JSONResponse)
async def health_check():
    """
    Health check endpoint for Kubernetes liveness/readiness probes.
    
    Returns:
        JSONResponse: Health status of the service
    """
    return JSONResponse(
        content={
            "status": "healthy",
            "service": "python-microservice"
        }
    )
