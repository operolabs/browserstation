# main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import ray
import logging

from .routes import router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    # Startup
    logger.info("Initializing Ray connection...")
    if not ray.is_initialized():
        ray.init(address="auto")
    logger.info("Ray initialized successfully")
    
    yield



app = FastAPI(
    title="BrowserStation",
    description="Opensource alternative to browser",
    version="2.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include the router
app.include_router(router)